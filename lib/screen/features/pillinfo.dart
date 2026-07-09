import 'package:flutter/material.dart';

class Pillinfo extends StatefulWidget {
  final Map<String, dynamic> pillData;

  const Pillinfo({super.key, required this.pillData});

  @override
  State<Pillinfo> createState() => _PillinfoState();
}

class _PillinfoState extends State<Pillinfo> {
  @override
  Widget build(BuildContext context) {
    final item = widget.pillData;
    final imageUrl = item['ITEM_IMAGE'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(item['ITEM_NAME'] ?? '약 정보'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              item['ITEM_NAME'] ?? '이름 없음',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              item['ENTP_NAME'] ?? '업체명 없음',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const Divider(height: 32),
            _infoRow('분류명', item['CLASS_NAME']),
            _infoRow('성상', item['COLOR_CLASS1']),
            _infoRow('모양', item['DRUG_SHAPE']),
            _infoRow('표시앞', item['PRINT_FRONT']),
            _infoRow('표시뒤', item['PRINT_BACK']),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
