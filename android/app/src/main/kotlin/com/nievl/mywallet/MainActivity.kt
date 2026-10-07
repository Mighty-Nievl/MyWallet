package com.nievl.mywallet

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (bukan FlutterActivity) agar local_auth/biometrik
// dan flutter_secure_storage bekerja stabil.
class MainActivity : FlutterFragmentActivity()
