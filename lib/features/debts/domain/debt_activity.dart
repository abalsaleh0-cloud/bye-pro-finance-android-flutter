/// An immutable event in the unified debt activity ledger.
final class DebtActivity {
  const DebtActivity({
    required this.id,
    required this.debtId,
    required this.eventType,
    required this.direction,
    required this.counterparty,
    required this.amountMinorUnits,
    required this.occurredAt,
    this.note,
  });

  final String id;
  final String debtId;
  final String eventType;
  final String direction;
  final String counterparty;
  final int amountMinorUnits;
  final DateTime occurredAt;
  final String? note;
}
