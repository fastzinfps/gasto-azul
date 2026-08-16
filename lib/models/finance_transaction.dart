enum TransactionType { income, expense }

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.description,
    required this.account,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.category = 'Outros',
    this.source = 'manual',
  });

  final String id;
  final String description;
  final String account;
  final double amount;
  final TransactionType type;
  final DateTime createdAt;
  final String category;
  final String source;
}
