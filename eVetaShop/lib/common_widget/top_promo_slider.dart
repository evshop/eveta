import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class TopPromoSlider extends StatelessWidget {
  const TopPromoSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: SizedBox(
          height: 150.0,
          width: double.infinity,
          child: CarouselSlider(
            options: CarouselOptions(
              height: 150,
              viewportFraction: 1,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 500),
            ),
            items: const [
              Image(
                image: AssetImage("assets/images/ic_discount.png"),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ],
          )),
    );
  }
}
