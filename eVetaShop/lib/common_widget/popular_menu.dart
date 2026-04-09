import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PopularMenu extends StatelessWidget {
  const PopularMenu({super.key});

  final double _size = 55.0;
  final double _customFontSize = 13;
  final String _defaultFontFamily = 'Roboto-Light.ttf';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFF2F3F7)),
                child: RawMaterialButton(
                  onPressed: () {},
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.account_balance,
                    color: Color(0xFFAB436B),
                  ),
                ),
              ),
              Text(
                "Popular",
                style: TextStyle(
                    color: Color(0xFF969696),
                    fontFamily: _defaultFontFamily,
                    fontSize: _customFontSize),
              )
            ],
          ),
          Column(
            children: <Widget>[
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFF2F3F7)),
                child: RawMaterialButton(
                  onPressed: () {},
                  shape: const CircleBorder(),
                  child: const Icon(
                    FontAwesomeIcons.clock,
                    color: Color(0xFFC1A17C),
                  ),
                ),
              ),
              Text(
                "Flash Sell",
                style: TextStyle(
                    color: Color(0xFF969696),
                    fontFamily: _defaultFontFamily,
                    fontSize: _customFontSize),
              )
            ],
          ),
          Column(
            children: <Widget>[
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFF2F3F7)),
                child: RawMaterialButton(
                  onPressed: () {},
                  shape: const CircleBorder(),
                  child: const Icon(
                    FontAwesomeIcons.truck,
                    color: Color(0xFF5EB699),
                  ),
                ),
              ),
              Text(
                "eVeta Store",
                style: TextStyle(
                    color: Color(0xFF969696),
                    fontFamily: _defaultFontFamily,
                    fontSize: _customFontSize),
              )
            ],
          ),
          Column(
            children: <Widget>[
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFF2F3F7)),
                child: RawMaterialButton(
                  onPressed: () {},
                  shape: const CircleBorder(),
                  child: const Icon(
                    FontAwesomeIcons.gift,
                    color: Color(0xFF4D9DA7),
                  ),
                ),
              ),
              Text(
                "Voucher",
                style: TextStyle(
                    color: Color(0xFF969696),
                    fontFamily: _defaultFontFamily,
                    fontSize: _customFontSize),
              )
            ],
          )
        ],
      ),
    );
  }
}
