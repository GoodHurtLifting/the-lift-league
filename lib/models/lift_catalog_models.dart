class LiftCatalogItem {
  final int id;                 // catalogId (DB PK)
  final String name;
  final String primaryGroup;    // Chest/Back/etc.
  final String? equipment;      // Barbell/Dumbbell/Bodyweight/…
  final bool isBodyweightCapable;
  final bool isDumbbellCapable;
  final bool unilateral;

  LiftCatalogItem({
    required this.id,
    required this.name,
    required this.primaryGroup,
    this.equipment,
    this.isBodyweightCapable = false,
    this.isDumbbellCapable = false,
    this.unilateral = false,
  });

  factory LiftCatalogItem.fromRow(Map<String, Object?> r) => LiftCatalogItem(
    id: (r['catalogId'] ?? r['id']) as int,
    name: r['name'] as String,
    primaryGroup: (r['primaryGroup'] as String?) ?? '',
    equipment: r['equipment'] as String?,
    isBodyweightCapable: (r['isBodyweightCapable'] as int? ?? 0) != 0,
    isDumbbellCapable: (r['isDumbbellCapable'] as int? ?? 0) != 0,
    unilateral: (r['unilateral'] as int? ?? 0) != 0,
  );
}
