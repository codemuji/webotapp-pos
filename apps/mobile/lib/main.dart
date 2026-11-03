import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/cart/cart_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: GroceryPosMobileApp(),
    ),
  );
}

class GroceryPosMobileApp extends StatelessWidget {
  const GroceryPosMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery POS Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981), // Emerald
          primary: const Color(0xFF10B981),
        ),
        fontFamily: 'Roboto',
      ),
      home: const CartScreen(),
    );
  }
}
