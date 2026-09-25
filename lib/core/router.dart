import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/catalog/categories_screen.dart';
import '../features/catalog/product_list_screen.dart';
import '../features/catalog/search_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/checkout/order_success_screen.dart';
import '../features/home/home_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/product/product_detail_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/wishlist/wishlist_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/otp',
      builder: (_, state) => OtpScreen(phone: state.uri.queryParameters['phone'] ?? ''),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/cart', builder: (_, _) => const CartScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
        ),
      ],
    ),
    GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen()),
    GoRoute(
      path: '/products',
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return ProductListScreen(
          title: q['title'] ?? 'Products',
          categoryId: q['category'],
          collection: ProductCollection.values.asNameMap()[q['collection']] ?? ProductCollection.all,
        );
      },
    ),
    GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
    GoRoute(
      path: '/product/:id',
      builder: (_, state) => ProductDetailScreen(
        key: ValueKey(state.pathParameters['id']),
        productId: state.pathParameters['id']!,
        heroTag: state.extra as String?,
      ),
    ),
    GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
    GoRoute(
      path: '/order-success/:id',
      builder: (_, state) => OrderSuccessScreen(orderId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
    GoRoute(
      path: '/orders/:id',
      builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
    ),
  ],
  errorBuilder: (_, state) => Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
);
