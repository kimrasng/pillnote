import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MenubarItme extends StatelessWidget {
  final String title;
  final dynamic iconsvg;
  final List<Widget> pages;
  final List<String> itemName;

  const MenubarItme({
    super.key,
    required this.title,
    required this.iconsvg,
    required this.pages,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    Widget iconWidget;
    if (iconsvg is IconData) {
      iconWidget = Icon(iconsvg as IconData, color: const Color(0xFF2563EB), size: screenWidth * 0.06);
    } else if (iconsvg is String) {
      iconWidget = SvgPicture.asset(
        iconsvg as String,
        colorFilter: const ColorFilter.mode(Color(0xFF2563EB), BlendMode.srcIn),
        width: screenWidth * 0.06,
        height: screenWidth * 0.06,
      );
    } else {
      iconWidget = const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: iconWidget,
              ),
              SizedBox(width: screenWidth * 0.04),
              Text(
                title,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (itemName.isNotEmpty) ...[
            SizedBox(height: screenWidth * 0.04),
            ...List.generate(itemName.length, (index) {
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (index < pages.length) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => pages[index]),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              itemName[index],
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: screenWidth * 0.05,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (index < itemName.length - 1)
                    Divider(color: Colors.grey.shade200, height: 1),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
