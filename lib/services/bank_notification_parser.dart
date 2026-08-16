import '../models/finance_transaction.dart';

class ParsedBankNotification {
  const ParsedBankNotification({
    required this.account,
    required this.amount,
    required this.type,
    required this.description,
    required this.rawText,
  });

  final String account;
  final double amount;
  final TransactionType type;
  final String description;
  final String rawText;
}

class BankNotificationParser {
  static final RegExp _money = RegExp(
    r'R\$\s*([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2}|[0-9]+,[0-9]{2}|[0-9]+(?:\.[0-9]{2})?)',
    caseSensitive: false,
  );

  static ParsedBankNotification? parse(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString();
    final text = (data['text'] ?? '').toString();
    final packageName = (data['packageName'] ?? '').toString();
    final combined = '$title $text $packageName';
    final lower = _normalize(combined);

    final account = _detectAccount(lower);
    if (account == null) return null;

    final match = _money.firstMatch(combined);
    if (match == null) return null;

    final amount = _parseBrazilianMoney(match.group(1)!);
    if (amount <= 0) return null;

    final type = _detectType(lower);
    if (type == null) return null;

    final description = _descriptionFor(type, lower);

    return ParsedBankNotification(
      account: account,
      amount: amount,
      type: type,
      description: description,
      rawText: '$title — $text',
    );
  }

  static String? _detectAccount(String text) {
    if (text.contains('picpay')) return 'PicPay';
    if (text.contains('banco do brasil') ||
        text.contains('br.com.bb') ||
        text.contains('bb android')) {
      return 'Banco do Brasil';
    }
    return null;
  }

  static TransactionType? _detectType(String text) {
    const incomeWords = [
      'recebeu',
      'recebido',
      'pix recebido',
      'creditado',
      'credito recebido',
      'depositado',
    ];
    const expenseWords = [
      'pix feito',
      'pix enviado',
      'transferencia realizada',
      'pagamento realizado',
      'compra aprovada',
      'compra realizada',
      'debito',
      'pago',
    ];

    if (incomeWords.any(text.contains)) return TransactionType.income;
    if (expenseWords.any(text.contains)) return TransactionType.expense;
    return null;
  }

  static String _descriptionFor(TransactionType type, String text) {
    if (text.contains('pix')) {
      return type == TransactionType.income ? 'Pix recebido' : 'Pix enviado';
    }
    if (text.contains('compra')) return 'Compra';
    if (text.contains('pagamento')) return 'Pagamento';
    return type == TransactionType.income ? 'Receita detectada' : 'Gasto detectado';
  }

  static double _parseBrazilianMoney(String raw) {
    final value = raw.contains(',')
        ? raw.replaceAll('.', '').replaceAll(',', '.')
        : raw;
    return double.tryParse(value) ?? 0;
  }

  static String _normalize(String value) {
    const accents = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c',
    };
    var result = value.toLowerCase();
    accents.forEach((from, to) => result = result.replaceAll(from, to));
    return result;
  }
}
