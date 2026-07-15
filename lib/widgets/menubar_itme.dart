import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MenubarItme extends StatelessWidget {
  final String title;
  final dynamic iconsvg;
  final List<Widget> pages;
  final List<String> itemName;

  MenubarItme({
    super.key,
    required this.title,
    required this.iconsvg,
    required this.pages,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;

    if (iconsvg is IconData) {
      iconWidget = Icon(iconsvg as IconData, color: Colors.black);
    } else if (iconsvg is String) {
      iconWidget = SvgPicture.asset(
        iconsvg as String,
        colorFilter: ColorFilter.mode(Colors.black, BlendMode.srcIn),
        width: 24,
        height: 24,
      );
    } else {
      iconWidget = SizedBox.shrink();
    }

    return Container(
      padding: .all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF4F5F7),
        borderRadius: .circular(15),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              iconWidget,
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: .bold,
                ),
              ),
            ],
          ),
          if (itemName.isNotEmpty) ...[
            SizedBox(height: 20),
            ...List.generate(itemName.length, (index) {
              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (index < pages.length) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => pages[index]),
                        );
                      }
                    },
                    behavior: .opaque,
                    child: Padding(
                      padding: .symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          Text(
                            itemName[index],
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (index < itemName.length - 1)
                    Divider(color: Colors.black12, height: 20),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
