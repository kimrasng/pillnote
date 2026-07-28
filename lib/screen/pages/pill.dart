import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/features/pillsearch.dart';
import 'package:pillnote/screen/management/pilmanagement.dart';
import 'package:pillnote/screen/management/pill_group_edit.dart';

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
    final double screenHeight = size.height;
    final pills = Controller.getPills();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            "복약 관리",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.05,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF2563EB),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(
              fontSize: screenWidth * 0.042,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: TextStyle(fontSize: screenWidth * 0.04),
            tabs: const [
              Tab(text: "오늘 먹을 약"),
              Tab(text: "내 약 상자"),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (context) => Pillsearch()),
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
        body: TabBarView(
          children: [
            _buildTodaySchedule(pills, screenWidth, screenHeight),
            pills.isEmpty
                ? _buildEmptyState(screenWidth, screenHeight)
                : _buildPillList(pills, screenWidth, screenHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySchedule(
    List<Map<String, dynamic>> pills,
    double screenWidth,
    double screenHeight,
  ) {
    final today = DateTime.now().toString().split(' ')[0];
    final history = Controller.getHistoryByDate(today);

    final activePills = pills.where((p) {
      if (p['startDate'] == null || p['endDate'] == null) return false;
      return today.compareTo(p['startDate']) >= 0 &&
          today.compareTo(p['endDate']) <= 0;
    }).toList();

    final groups = Controller.getGroups();
    final activeGroups = groups.where((g) {
      if (g['startDate'] == null || g['endDate'] == null) return false;
      return today.compareTo(g['startDate']) >= 0 &&
          today.compareTo(g['endDate']) <= 0;
    }).toList();

    if (activePills.isEmpty && activeGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.08),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: screenWidth * 0.15,
                color: Colors.grey.shade300,
              ),
            ),
            SizedBox(height: screenHeight * 0.03),
            Text(
              "오늘 먹을 약이 없습니다.",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(screenWidth * 0.05),
      children: [
        ...activeGroups.map(
          (group) => _buildGroupCard(group, history, screenWidth, screenHeight),
        ),
        ...activePills.map(
          (pill) => _buildPillCard(pill, history, screenWidth, screenHeight),
        ),
        SizedBox(height: screenHeight * 0.1),
      ],
    );
  }

  Widget _buildGroupCard(
    Map<String, dynamic> group,
    List<Map<String, dynamic>> history,
    double screenWidth,
    double screenHeight,
  ) {
    final times = group['times'] as List? ?? [];
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: screenWidth * 0.06,
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: Text(
                    group['name'] ?? '처방전 묶음',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.048,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.025),
            ...times.map((time) {
              final isTaken = history.any(
                (h) =>
                    h['groupId'] == group['id'] && h['scheduledTime'] == time,
              );
              return _buildIntakeButton(
                time: time,
                isTaken: isTaken,
                onTap: () async {
                  await Controller.recordGroupIntake(group['id'], time);
                  setState(() {});
                  _showSuccessSnackBar("$time 복용을 완료했습니다!");
                },
                dosageText: "묶음 약 전체 복용",
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPillCard(
    Map<String, dynamic> pill,
    List<Map<String, dynamic>> history,
    double screenWidth,
    double screenHeight,
  ) {
    final times = pill['times'] as List? ?? [];
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.medication_outlined,
                    color: Colors.black87,
                    size: screenWidth * 0.06,
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: Text(
                    pill['ITEM_NAME'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.045,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.025),
            ...times.map((time) {
              final isTaken = history.any(
                (h) => h['pillId'] == pill['id'] && h['scheduledTime'] == time,
              );
              return _buildIntakeButton(
                time: time,
                isTaken: isTaken,
                onTap: () async {
                  final double currentStock = (pill['stock'] ?? 0).toDouble();
                  final double dosage = (pill['dosage'] ?? 1.0).toDouble();
                  if (currentStock < dosage) {
                    _showStockWarning(screenWidth, screenHeight);
                    return;
                  }
                  await Controller.recordIntake(pill['id'], time);
                  setState(() {});
                  _showSuccessSnackBar(
                    "$time 복용 완료! (남은 약: ${(currentStock - dosage).toStringAsFixed(1)}정)",
                  );
                },
                dosageText: "1회 ${pill['dosage'] ?? 1.0}정 먹기",
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntakeButton({
    required String time,
    required bool isTaken,
    required VoidCallback onTap,
    required String dosageText,
    required double screenWidth,
    required double screenHeight,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
      child: InkWell(
        onTap: isTaken ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.018,
            horizontal: screenWidth * 0.05,
          ),
          decoration: BoxDecoration(
            color: isTaken ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTaken ? const Color(0xFFBBF7D0) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isTaken ? Icons.check_circle : Icons.add_circle_outline,
                color: isTaken
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF2563EB),
                size: screenWidth * 0.07,
              ),
              SizedBox(width: screenWidth * 0.04),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$time 복용",
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.bold,
                      color: isTaken ? const Color(0xFF16A34A) : Colors.black87,
                    ),
                  ),
                  Text(
                    dosageText,
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isTaken)
                Text(
                  "완료",
                  style: TextStyle(
                    color: const Color(0xFF16A34A),
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: screenWidth * 0.05,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    final screenWidth = MediaQuery.of(context).size.width;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontSize: screenWidth * 0.038,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showStockWarning(double screenWidth, double screenHeight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "약이 부족해요!",
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "남은 약이 거의 없어요. 새로 처방받거나 사오셔야 해요.",
          style: TextStyle(fontSize: screenWidth * 0.042),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "알겠어요",
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
                MaterialPageRoute<void>(builder: (context) => Pillsearch()),
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
              "약 묶음 (처방전)",
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
            "내 약 목록",
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
          icon: Icon(Icons.auto_fix_high_outlined, size: screenWidth * 0.05),
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
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
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
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "${(group['pillIds'] as List).length}개의 약이 들어있어요",
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
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "복용  (~${pill['endDate']})",
                      style: TextStyle(
                        color: const Color(0xFF2563EB),
                        fontSize: screenWidth * 0.028,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
