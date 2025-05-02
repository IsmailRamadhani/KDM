class Item {
  int? id;
  String nama;
  int qty;
  String seri;
  String brand;

  Item({
    this.id,
    required this.nama,
    required this.qty,
    required this.seri,
    required this.brand,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'nama': nama, 'qty': qty, 'seri': seri, 'brand': brand};
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      nama: map['nama'],
      qty: map['qty'],
      seri: map['seri'],
      brand: map['brand'],
    );
  }
}
