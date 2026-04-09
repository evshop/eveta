import 'package:flutter/material.dart';
import 'package:eveta/common_widget/app_bar_widget.dart';
import 'package:eveta/components/brand_home_page.dart';
import 'package:eveta/components/category_slider.dart';
import 'package:eveta/common_widget/search_widget.dart';
import 'package:eveta/components/shop_home_page.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';

class SubCategoryScreen extends StatelessWidget {
  const SubCategoryScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: appBarWidget(context),
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          bottom: false,
          left: false,
          right: false,
          child: Column(
            children: <Widget>[
              const SearchWidget(),
              const SizedBox(height: 0),
              PreferredSize(
                preferredSize: const Size.fromHeight(50.0),
                child: TabBar(
                  isScrollable: true,
                  labelColor: Colors.black,
                  tabs: const [
                    Tab(
                      text: 'Sub Categories',
                    ),
                    Tab(
                      text: 'Brands',
                    ),
                    Tab(
                      text: 'Shops',
                    )
                  ], // list of tabs
                ),
              ),
              const SizedBox(height: 0),
              Expanded(
                child: TabBarView(
                  children: [
                    SizedBox.expand(
                      child: Container(
                        color: Colors.white,
                        child: CategoryPage(
                          slug: 'categories/?parent=$slug',
                          isSubList: true,
                        ),
                      ),
                    ),
                    SizedBox.expand(
                      child: Container(
                        color: Colors.white,
                        child: BrandHomePage(
                          slug: 'brands/?limit=20&page=1&category=$slug',
                          isSubList: true,
                        ),
                      ),
                    ),
                    SizedBox.expand(
                      child: Container(
                        color: Colors.white,
                        child: ShopHomePage(
                          slug: 'category/shops/$slug/?page=1&limit=15',
                          isSubList: true,
                        ),
                      ),
                    ) // class name
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavBarWidget(
          currentIndex: 1, // Categorías
          onTap: (index) {
            // Esta pantalla se abre encima del PageView principal.
            // Para evitar que se vea el nav duplicado, volvemos atrás.
            Navigator.maybePop(context);
          },
        ),
      ),
    );
  }
}
