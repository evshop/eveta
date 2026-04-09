import 'package:flutter/material.dart';

class SearchWidget extends StatelessWidget {
  const SearchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Theme(
          data: Theme.of(context).copyWith(
            primaryColor: Colors.grey[600],
          ),
          child: TextField(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                borderSide: const BorderSide(
                  width: 0,
                  style: BorderStyle.none,
                ),
              ),
              filled: true,
              prefixIcon: const Icon(Icons.search),
              fillColor: const Color(0xFFF2F4F5),
              hintStyle: TextStyle(color: Colors.grey[600]),
              hintText: "What would your like to buy?",
            ),
            autofocus: false,
          )),
    );
  }
}
