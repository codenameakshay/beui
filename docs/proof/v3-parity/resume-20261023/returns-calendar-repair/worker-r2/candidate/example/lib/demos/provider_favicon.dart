import 'package:flutter/material.dart';

Widget providerFavicon(String url, Widget fallback) => Image.network(
  url,
  width: 16,
  height: 16,
  fit: BoxFit.contain,
  errorBuilder: (_, _, _) => fallback,
);
