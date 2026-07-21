import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/features/pillsearch.dart';

class Pill extends StatefulWidget {
  const Pill({super.key});

  @override
  State<Pill> createState() => _PillState();
}

class _PillState extends State<Pill> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final pills = Controller.getPills();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "내 약 관리",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => const Pillsearch()),
              );
              setState(() {});
            },
            icon: const Icon(Icons.add, color: Colors.black),
          ),
        ],
      ),
      body: pills.isEmpty
          ? _buildEmptyState(screenWidth)
          : _buildPillList(pills, screenWidth),
    );
  }

  Widget _buildEmptyState(double screenWidth) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_liquid,
            size: screenWidth * 0.15,
            color: Colors.black12,
          ),
          const SizedBox(height: 10),
          Text(
            "등록된 약이 없습니다.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: screenWidth * 0.035,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => const Pillsearch()),
              );
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("약 검색하러 가기"),
          ),
        ],
      ),
    );
  }

  Widget _buildPillList(List<Map<String, dynamic>> pills, double screenWidth) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pills.length,
      itemBuilder: (context, index) {
        final pill = pills[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: screenWidth * 0.2,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: pill['ITEM_IMAGE'] != null && pill['ITEM_IMAGE'].isNotEmpty
                    ? Image.network(
                        pill['ITEM_IMAGE'],
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.medication, color: Colors.grey),
                      )
                    : Icon(Icons.medication, color: Colors.grey),
              ),
            ),
            title: Text(
              pill['ITEM_NAME'] ?? '이름 없음',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              pill['ENTP_NAME'] ?? '',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("약 삭제"),
                    content: const Text("이 약을 목록에서 삭제하시겠습니까?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("취소"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("삭제", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Controller.removePill(pill['id']);
                  setState(() {});
                }
              },
            ),
          ),
        );
      },
    );
  }
}
