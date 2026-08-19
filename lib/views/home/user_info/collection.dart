import 'package:chatapp/widgets/book_card.dart';
import 'package:flutter/material.dart';

class Collection extends StatelessWidget {
  const Collection({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 11,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        childAspectRatio: 0.7,
      ),
      itemBuilder: (context, index) {
        return BookCard();
      },
    );
  }
}
