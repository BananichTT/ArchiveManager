class StoreItem {
  final String id;
  final String workType;
  final String networkType;
  final String storeName;
  final String storeNum;
  final String address;

  StoreItem({
    required this.id,
    required this.workType,
    required this.networkType,
    required this.storeName,
    required this.storeNum,
    required this.address,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: json['id'] ?? '',
      workType: json['work_type'] ?? '',
      networkType: json['network_type'] ?? '',
      storeName: json['store_name'] ?? '',
      storeNum: json['store_num'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'work_type': workType,
      'network_type': networkType,
      'store_name': storeName,
      'store_num': storeNum,
      'address': address,
    };
  }
}
