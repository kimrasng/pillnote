import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/services/api_client.dart';

class Pillinfo extends StatefulWidget {
  final String pillSEQ;
  final bool isLocal;

  const Pillinfo({super.key, required this.pillSEQ, required this.isLocal});

  @override
  State<Pillinfo> createState() => _PillinfoState();
}

class _PillinfoState extends State<Pillinfo> {
  Map<String, dynamic>? pillData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPillData();
  }

  Future<void> _fetchPillData() async {
    if (widget.isLocal) {
      final localPills = Controller.getPills();
      final localPill = localPills.firstWhere(
        (p) => p['ITEM_SEQ'] == widget.pillSEQ || p['id'] == widget.pillSEQ,
        orElse: () => {},
      );

      if (localPill.isNotEmpty) {
        setState(() {
          pillData = localPill;
          isLoading = false;
        });
        return;
      }
    }

    try {
      final item = await ApiClient.instance.drugDetail(widget.pillSEQ);
      if (!mounted) return;
      setState(() {
        pillData = item;
        isLoading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          errorMessage = error.message;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          errorMessage = '서버에 연결할 수 없습니다.';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('약 정보', style: TextStyle(fontSize: screenWidth * 0.05)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null || pillData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('약 정보', style: TextStyle(fontSize: screenWidth * 0.05)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessage ?? '약 정보를 불러오지 못했습니다.',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  color: Colors.grey,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  _fetchPillData();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final item = pillData!;
    final imageUrl = item['ITEM_IMAGE'] ?? '';
    final consumerInfo = Map<String, dynamic>.from(
      item['consumerInfo'] as Map? ?? const {},
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          item['ITEM_NAME'] ?? '약 정보',
          style: TextStyle(fontSize: screenWidth * 0.05),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: screenWidth * 0.05),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.06,
                screenWidth * 0.04,
                screenWidth * 0.06,
                screenHeight * 0.15,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isNotEmpty)
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.05,
                          ),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.05,
                          ),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: screenHeight * 0.25,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: double.infinity,
                                  height: screenHeight * 0.25,
                                  color: Colors.grey.shade50,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: screenWidth * 0.15,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    item['ITEM_NAME'] ?? '이름 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    item['ENTP_NAME'] ?? '업체명 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(),
                  ),
                  _buildDetailRow('분류명', item['CLASS_NAME'], screenWidth),
                  _buildDetailRow('성상', item['COLOR_CLASS1'], screenWidth),
                  _buildDetailRow('모양', item['DRUG_SHAPE'], screenWidth),
                  _buildDetailRow('표시앞', item['PRINT_FRONT'], screenWidth),
                  _buildDetailRow('표시뒤', item['PRINT_BACK'], screenWidth),
                  if (consumerInfo.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(),
                    ),
                    _buildConsumerSection(
                      '효능·효과',
                      consumerInfo['efficacy'],
                      screenWidth,
                    ),
                    _buildConsumerSection(
                      '복용 방법',
                      consumerInfo['usage'],
                      screenWidth,
                    ),
                    _buildConsumerSection(
                      '주의사항',
                      consumerInfo['precautions'] ?? consumerInfo['warning'],
                      screenWidth,
                    ),
                    _buildConsumerSection(
                      '부작용',
                      consumerInfo['sideEffects'],
                      screenWidth,
                    ),
                    _buildConsumerSection(
                      '보관 방법',
                      consumerInfo['storage'],
                      screenWidth,
                    ),
                  ],
                ],
              ),
            ),
            if (!widget.isLocal)
              Positioned(
                left: screenWidth * 0.06,
                right: screenWidth * 0.06,
                bottom: 20,
                child: SizedBox(
                  width: double.infinity,
                  height: screenHeight * 0.07,
                  child: FilledButton(
                    onPressed: () async {
                      final TextEditingController stockController =
                          TextEditingController(text: "30");
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text(
                            "보유 수량 입력",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("보유하고 계신 약의 총 수량을 입력해주세요"),
                              SizedBox(height: screenHeight * 0.02),
                              TextField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: screenWidth * 0.045),
                                decoration: const InputDecoration(
                                  labelText: "보유 수량",
                                  suffixText: "정",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("취소"),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("추가"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final int stock =
                            int.tryParse(stockController.text) ?? 0;
                        await Controller.addPill(item, stock);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('등록되었습니다'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(screenWidth * 0.04),
                      ),
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    child: Text(
                      "내 약 상자에 추가",
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: screenWidth * 0.2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.038,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value ?? '-').toString(),
              style: TextStyle(
                fontSize: screenWidth * 0.038,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsumerSection(
    String title,
    dynamic value,
    double screenWidth,
  ) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: screenWidth * 0.042,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: screenWidth * 0.037,
              height: 1.55,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
