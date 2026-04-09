import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/components/app_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

PreferredSizeWidget appBarWidget(BuildContext context, {bool showMenuButton = true}) {
  final canPop = Navigator.canPop(context);
  return AppBar(
    elevation: 0.0,
    centerTitle: true,
    automaticallyImplyLeading: false,
    leading: showMenuButton
        ? (canPop
            ? const EvetaCircularBackButton(
                variant: EvetaCircularBackVariant.onLightBackground,
              )
            : null)
        : const SizedBox(width: 0),
    leadingWidth: !showMenuButton ? 0 : (canPop ? 56 : null),
    title: const Text(
      "eVeta",
      style: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 22,
      ),
    ),
    actions: <Widget>[
      IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AppSignIn()),
          );
        },
        icon: const Icon(FontAwesomeIcons.user),
        color: const Color(0xFF323232),
      ),
    ],
  );
}
