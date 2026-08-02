import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/features/pillsearch.dart';
import 'package:pillnote/screen/management/pilmanagement.dart';
import 'package:pillnote/screen/management/pill_group_edit.dart';

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
    final double screenHeight = size.height;
    final pills = Controller.getPills();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "내 약 상자",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.05,
          ),
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
            icon: Icon(
              Icons.add_circle_outline,
              color: Colors.black,
              size: screenWidth * 0.07,
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
        ],
      ),
      body: pills.isEmpty
          ? _buildEmptyState(screenWidth, screenHeight)
          : _buildPillList(pills, screenWidth, screenHeight),
    );
  }

  Widget _buildEmptyState(double screenWidth, double screenHeight) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.08),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medication_liquid_outlined,
              size: screenWidth * 0.15,
              color: Colors.grey.shade300,
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          Text(
            "등록된 약이 없습니다.",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: screenHeight * 0.04),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (context) => const Pillsearch()),
              );
              setState(() {});
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: screenHeight * 0.018,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.search),
            label: Text(
              "약 검색하러 가기",
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillList(
    List<Map<String, dynamic>> pills,
    double screenWidth,
    double screenHeight,
  ) {
    final groups = Controller.getGroups();

    return ListView(
      padding: EdgeInsets.all(screenWidth * 0.05),
      children: [
        if (groups.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(
              left: screenWidth * 0.02,
              bottom: screenHeight * 0.015,
            ),
            child: Text(
              "처방전 묶음",
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          ...groups.map(
            (group) =>
                _buildGroupManagementCard(group, screenWidth, screenHeight),
          ),
          SizedBox(height: screenHeight * 0.03),
        ],

        Padding(
          padding: EdgeInsets.only(
            left: screenWidth * 0.02,
            bottom: screenHeight * 0.015,
          ),
          child: Text(
            "등록된 약",
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        ...pills.map(
          (pill) => _buildPillManagementCard(pill, screenWidth, screenHeight),
        ),

        SizedBox(height: screenHeight * 0.04),
        FilledButton.tonalIcon(
          onPressed: () => _navigateToGroupEdit(context),
          icon: Icon(Icons.link, size: screenWidth * 0.05),
          label: Text(
            "여러 약 하나로 묶기",
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
            foregroundColor: const Color(0xFF2563EB),
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.15),
      ],
    );
  }

  Widget _buildGroupManagementCard(
    Map<String, dynamic> group,
    double screenWidth,
    double screenHeight,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.015),
      child: Material(
        color: const Color(0xFFEFF6FF),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFDBEAFE), width: 1),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(screenWidth * 0.045),
          leading: Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: const Color(0xFF2563EB),
              size: screenWidth * 0.06,
            ),
          ),
          title: Text(
            group['name'] ?? '묶음',
            style: TextStyle(
              fontSize: screenWidth * 0.042,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A8A),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "${(group['pillIds'] as List).length}개의 약이 포함됨",
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: Colors.black54,
              ),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.grey.shade400,
            size: screenWidth * 0.05,
          ),
          onTap: () => _navigateToGroupEdit(context, group: group),
        ),
      ),
    );
  }

  Widget _buildPillManagementCard(
    Map<String, dynamic> pill,
    double screenWidth,
    double screenHeight,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.015),
      child: Material(
        color: const Color(0xFFEFF6FF),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFDBEAFE), width: 1),
        ),
        child: ListTile(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Pilmanagement(pill: pill),
              ),
            );
            setState(() {});
          },
          contentPadding: EdgeInsets.all(screenWidth * 0.045),
          leading: Container(
            width: screenWidth * 0.16,
            height: screenWidth * 0.16,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: pill['ITEM_IMAGE'] != null && pill['ITEM_IMAGE'].isNotEmpty
                  ? Image.network(pill['ITEM_IMAGE'], fit: BoxFit.contain)
                  : Icon(
                      Icons.medication_outlined,
                      color: Colors.grey.shade400,
                      size: screenWidth * 0.07,
                    ),
            ),
          ),
          title: Text(
            pill['ITEM_NAME'] ?? '이름 없음',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.042,
              color: const Color(0xFF1E3A8A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                pill['ENTP_NAME'] ?? '',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: screenWidth * 0.035,
                ),
              ),
              if (pill['startDate'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${pill['dosage'] ?? 1.0}정씩",
                          style: TextStyle(
                            color: const Color(0xFF2563EB),
                            fontSize: screenWidth * 0.028,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...(pill['times'] as List? ?? []).map((time) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          time.toString(),
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: screenWidth * 0.028,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                    ],
                  ),
                ),
            ],
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: Colors.grey.shade400,
            size: screenWidth * 0.05,
          ),
        ),
      ),
    );
  }


  void _navigateToGroupEdit(
    BuildContext context, {
    Map<String, dynamic>? group,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PillGroupEdit(group: group)),
    );
    setState(() {});
  }
}
