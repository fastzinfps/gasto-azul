import 'dart:async';
import 'package:flutter/material.dart';

import 'models/finance_transaction.dart';
import 'services/bank_notification_parser.dart';
import 'services/notification_bridge.dart';

void main() {
  runApp(const GastoAzulApp());
}

class GastoAzulApp extends StatelessWidget {
  const GastoAzulApp({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1769FF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gasto Azul',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F5FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const FinanceHomePage(),
    );
  }
}

class FinanceHomePage extends StatefulWidget {
  const FinanceHomePage({super.key});

  @override
  State<FinanceHomePage> createState() => _FinanceHomePageState();
}

class _FinanceHomePageState extends State<FinanceHomePage>
    with WidgetsBindingObserver {
  final _bridge = NotificationBridge();
  StreamSubscription<Map<String, dynamic>>? _subscription;

  final Map<String, double> _balances = {
    'Banco do Brasil': 0,
    'PicPay': 0,
  };

  final List<FinanceTransaction> _transactions = [];
  final Set<String> _processedNotificationKeys = {};
  int _index = 0;
  bool _balanceVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _bridge.notifications.listen(_handleRawNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPending();
    }
  }

  Future<void> _loadPending() async {
    try {
      final pending = await _bridge.getPendingNotifications();
      for (final item in pending) {
        await _handleRawNotification(item);
      }
    } catch (_) {
      // Em plataformas sem o canal Android, o app continua funcionando manualmente.
    }
  }

  Future<void> _handleRawNotification(Map<String, dynamic> raw) async {
    final notificationKey = [
      raw['packageName'] ?? '',
      raw['postTime'] ?? '',
      raw['title'] ?? '',
      raw['text'] ?? '',
    ].join('|');

    if (_processedNotificationKeys.contains(notificationKey)) return;
    _processedNotificationKeys.add(notificationKey);

    final parsed = BankNotificationParser.parse(raw);
    if (parsed == null || !mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetectedTransactionSheet(parsed: parsed),
    );

    if (confirmed == true) {
      _addTransaction(
        description: parsed.description,
        account: parsed.account,
        amount: parsed.amount,
        type: parsed.type,
        source: 'notification',
      );
    }
  }

  double get _totalBalance =>
      _balances.values.fold<double>(0, (sum, value) => sum + value);

  double get _monthIncome => _transactions
      .where((t) =>
          t.type == TransactionType.income && _sameMonth(t.createdAt, DateTime.now()))
      .fold<double>(0, (sum, t) => sum + t.amount);

  double get _monthExpense => _transactions
      .where((t) =>
          t.type == TransactionType.expense && _sameMonth(t.createdAt, DateTime.now()))
      .fold<double>(0, (sum, t) => sum + t.amount);

  void _addTransaction({
    required String description,
    required String account,
    required double amount,
    required TransactionType type,
    String source = 'manual',
    String category = 'Outros',
  }) {
    if (amount <= 0 || !_balances.containsKey(account)) return;

    setState(() {
      _balances[account] = (_balances[account] ?? 0) +
          (type == TransactionType.income ? amount : -amount);
      _transactions.insert(
        0,
        FinanceTransaction(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          description: description,
          account: account,
          amount: amount,
          type: type,
          createdAt: DateTime.now(),
          source: source,
          category: category,
        ),
      );
    });
  }

  Future<void> _showManualTransaction() async {
    final result = await showModalBottomSheet<_ManualTransactionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualTransactionSheet(accounts: _balances.keys.toList()),
    );
    if (result == null) return;
    _addTransaction(
      description: result.description,
      account: result.account,
      amount: result.amount,
      type: result.type,
    );
  }

  Future<void> _editAccountBalance(String account) async {
    final controller = TextEditingController(
      text: (_balances[account] ?? 0).toStringAsFixed(2).replaceAll('.', ','),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Saldo do $account'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Saldo atual'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.replaceAll('.', '').replaceAll(',', '.'),
              );
              Navigator.pop(context, parsed);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (value != null) {
      setState(() => _balances[account] = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildTransactions(),
      _buildAccounts(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualTransaction,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Movimentação'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Movimentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Contas',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gasto Azul',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text('Seu dinheiro, mais fácil de entender.'),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Acesso às notificações',
              onPressed: _bridge.openNotificationAccessSettings,
              icon: const Icon(Icons.notifications_active_outlined),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1769FF), Color(0xFF4B8DFF)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SALDO TOTAL',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _balanceVisible = !_balanceVisible),
                    icon: Icon(
                      _balanceVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _balanceVisible ? _money(_totalBalance) : 'R\$ ••••••',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMiniCard(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Entradas',
                      value: _money(_monthIncome),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryMiniCard(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Saídas',
                      value: _money(_monthExpense),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle(title: 'Minhas contas'),
        const SizedBox(height: 12),
        ..._balances.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AccountCard(
              name: entry.key,
              balance: entry.value,
              onTap: () => _editAccountBalance(entry.key),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Últimas movimentações'),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          const _EmptyState()
        else
          ..._transactions.take(5).map(_transactionTile),
      ],
    );
  }

  Widget _buildTransactions() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        const Text(
          'Movimentações',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('Tudo que entrou e saiu das suas contas.'),
        const SizedBox(height: 22),
        if (_transactions.isEmpty)
          const _EmptyState()
        else
          ..._transactions.map(_transactionTile),
      ],
    );
  }

  Widget _buildAccounts() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        const Text(
          'Contas',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('Defina o saldo inicial e acompanhe cada banco.'),
        const SizedBox(height: 22),
        ..._balances.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AccountCard(
              name: entry.key,
              balance: entry.value,
              onTap: () => _editAccountBalance(entry.key),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leitura automática',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ative o acesso às notificações no Android. O protótipo analisa notificações de PicPay e Banco do Brasil e pede confirmação antes de lançar.',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _bridge.openNotificationAccessSettings,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Configurar notificações'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _transactionTile(FinanceTransaction transaction) {
    final income = transaction.type == TransactionType.income;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: income
              ? const Color(0xFFEAF8F0)
              : const Color(0xFFFFEEF0),
          child: Icon(
            income ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: income ? const Color(0xFF168A4B) : const Color(0xFFD43C4B),
          ),
        ),
        title: Text(
          transaction.description,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${transaction.account} • ${transaction.source == 'notification' ? 'Automático' : 'Manual'}',
        ),
        trailing: Text(
          '${income ? '+' : '-'} ${_money(transaction.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: income ? const Color(0xFF168A4B) : const Color(0xFFD43C4B),
          ),
        ),
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  const _SummaryMiniCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.balance,
    required this.onTap,
  });

  final String name;
  final double balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPicPay = name == 'PicPay';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: isPicPay
                      ? const Color(0xFFE8F8F2)
                      : const Color(0xFFFFF6D9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPicPay
                      ? Icons.account_balance_wallet_rounded
                      : Icons.account_balance_rounded,
                  color: isPicPay
                      ? const Color(0xFF00A868)
                      : const Color(0xFFB98600),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      _money(balance),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: const Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.auto_graph_rounded, size: 36),
            SizedBox(height: 10),
            Text(
              'Ainda não há movimentações',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 5),
            Text(
              'Cadastre uma movimentação ou ative a leitura das notificações.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectedTransactionSheet extends StatelessWidget {
  const _DetectedTransactionSheet({required this.parsed});
  final ParsedBankNotification parsed;

  @override
  Widget build(BuildContext context) {
    final income = parsed.type == TransactionType.income;
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        22 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Movimentação detectada',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Text(parsed.account, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(parsed.description),
          const SizedBox(height: 12),
          Text(
            '${income ? '+' : '-'} ${_money(parsed.amount)}',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: income ? const Color(0xFF168A4B) : const Color(0xFFD43C4B),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Ignorar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualTransactionResult {
  const _ManualTransactionResult({
    required this.description,
    required this.account,
    required this.amount,
    required this.type,
  });

  final String description;
  final String account;
  final double amount;
  final TransactionType type;
}

class _ManualTransactionSheet extends StatefulWidget {
  const _ManualTransactionSheet({required this.accounts});
  final List<String> accounts;

  @override
  State<_ManualTransactionSheet> createState() => _ManualTransactionSheetState();
}

class _ManualTransactionSheetState extends State<_ManualTransactionSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  late String _account;
  TransactionType _type = TransactionType.expense;

  @override
  void initState() {
    super.initState();
    _account = widget.accounts.first;
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          22,
          22,
          22,
          22 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nova movimentação',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Gasto'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Receita'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() => _type = value.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor (R\$)'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _account,
              decoration: const InputDecoration(labelText: 'Conta'),
              items: widget.accounts
                  .map((account) => DropdownMenuItem(
                        value: account,
                        child: Text(account),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _account = value);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final amount = double.tryParse(
                    _amount.text.replaceAll('.', '').replaceAll(',', '.'),
                  );
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(
                    context,
                    _ManualTransactionResult(
                      description: _description.text.trim().isEmpty
                          ? (_type == TransactionType.income ? 'Receita' : 'Gasto')
                          : _description.text.trim(),
                      account: _account,
                      amount: amount,
                      type: _type,
                    ),
                  );
                },
                child: const Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

String _money(double value) {
  final negative = value < 0;
  final absolute = value.abs().toStringAsFixed(2);
  final parts = absolute.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  final result = 'R\$ ${buffer.toString()},${parts[1]}';
  return negative ? '-$result' : result;
}
