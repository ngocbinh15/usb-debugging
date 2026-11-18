import 'package:flutter/material.dart';

import 'pages/usb_debugging_page.dart';

class UsbDebuggingApp extends StatelessWidget {
  const UsbDebuggingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'USB Debugging',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff00796b)),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff00796b),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const UsbDebuggingPage(),
  );
}
