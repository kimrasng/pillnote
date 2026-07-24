import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/features/pillsearch.dart';
import 'package:pillnote/screen/management/pilmanagement.dart';

class Pill extends StatefulWidget {
  Pill({super.key});

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
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "내 약 관리",
          style: TextStyle(color: Colors.black, fontWeight: .bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => Pillsearch(),
                ),
              );
              setState(() {});
            },
            icon: Icon(Icons.add, color: Colors.black),
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
        mainAxisAlignment: .center,
        children: [
          Icon(
            Icons.medication_liquid,
            size: screenWidth * 0.15,
            color: Colors.black12,
          ),
          SizedBox(height: 10),
          Text(
            "등록된 약이 없습니다.",
            style: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.035),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => Pillsearch(),
                ),
              );
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: .circular(10),
              ),
            ),
            child: Text("약 검색하러 가기"),
          ),
        ],
      ),
    );
  }

  Widget _buildPillList(List<Map<String, dynamic>> pills, double screenWidth) {
    return ListView.builder(
      padding: .all(16),
      itemCount: pills.length,
      itemBuilder: (context, index) {
        final pill = pills[index];
        return Container(
          margin: .only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: .circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Pilmanagement(pill: pill)),
              );
              setState(() {});
            },
            contentPadding: .all(12),
            leading: Container(
              width: screenWidth * 0.2,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: .circular(8),
              ),
              child: ClipRRect(
                borderRadius: .circular(8),
                child:
                    pill['ITEM_IMAGE'] != null && pill['ITEM_IMAGE'].isNotEmpty
                    ? Image.network(
                        pill['ITEM_IMAGE'],
                        fit: .contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.medication, color: Colors.grey),
                      )
                    : Icon(Icons.medication, color: Colors.grey),
              ),
            ),
            title: Text(
              pill['ITEM_NAME'] ?? '이름 없음',
              style: TextStyle(fontWeight: .bold, fontSize: 16),
              maxLines: 1,
              overflow: .ellipsis,
            ),
            subtitle: Text(
              pill['ENTP_NAME'] ?? '',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        );
      },
    );
  }
}
