import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storage = StorageService();

  UserModel? _currentUser;
  List<UserModel> _students = [];
  bool _isLoading = false;

  AuthProvider() {
    _initUser();
  }

  UserModel? get currentUser => _currentUser;
  List<UserModel> get students => _students;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin' || _currentUser?.role == 'teacher';
  bool get isLoading => _isLoading;

  Future<void> _initUser() async {
    _isLoading = true;
    notifyListeners();

    // 1. Initialize Google Sign-In singleton
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '840452215763-nr7tn8kc3jbhs1c0168cun6h536vi7mi.apps.googleusercontent.com',
      );
    } catch (e) {
      print('Error initializing Google Sign-In: $e');
    }

    // 2. Seed the database on startup if it's completely empty
    await _storage.seedDatabaseIfNeeded();

    // 3. Check if a user is already signed in via Firebase Auth
    final user = _auth.currentUser;
    if (user != null) {
      // Look up in both collections to find the profile
      var doc = await _db.collection('students').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        _currentUser = UserModel.fromJson(doc.data()!);
      } else {
        doc = await _db.collection('teachers').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          _currentUser = UserModel.fromJson(doc.data()!);
        }
      }
    }

    // 4. Fetch students list for the teacher dashboard/selection
    await fetchStudents();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchStudents() async {
    try {
      final snapshot = await _db.collection('students').get();
      _students = snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching students: $e');
    }
  }

  Future<void> signInWithGoogle({
    required String selectedRole, // 'student' or 'admin' / 'teacher'
    bool simulate = false,
    String? simulateEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String? email;
      String? displayName;
      String? uid;

      if (simulate && simulateEmail != null) {
        // Simulation mode for easy developer preview
        email = simulateEmail;
        displayName = simulateEmail.split('@').first.toUpperCase();
        displayName = displayName[0] + displayName.substring(1).toLowerCase();
        
        final collection = selectedRole == 'student' ? 'students' : 'teachers';
        final query = await _db.collection(collection).where('email', isEqualTo: email).limit(1).get();
        if (query.docs.isNotEmpty) {
          uid = query.docs.first.id;
        } else {
          // Use a persistent dummy UID based on email for the simulated session
          uid = 'sim_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
        }
      } else {
        // Real Google Sign-In Flow
        final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
        if (googleUser == null) {
          // User cancelled
          return;
        }

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          email = firebaseUser.email;
          displayName = firebaseUser.displayName;
          uid = firebaseUser.uid;
        }
      }

      if (email == null || uid == null) {
        throw Exception('Could not retrieve credentials from Google Account.');
      }

      final String collection = selectedRole == 'student' ? 'students' : 'teachers';

      // Check if user document already exists in the selected collection with a 10-second timeout
      DocumentSnapshot doc;
      try {
        doc = await _db.collection(collection).doc(uid).get().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception(
            'Connection to Firestore timed out.\n'
            'Please ensure:\n'
            '1. You have clicked "Create Database" in your Firebase Console under Cloud Firestore.\n'
            '2. Your phone has a working internet connection.'
          ),
        );
      } catch (e) {
        throw Exception('Firestore Database Error:\n${e.toString().replaceAll('Exception: ', '')}');
      }

      if (doc.exists && doc.data() != null) {
        _currentUser = UserModel.fromJson(doc.data() as Map<String, dynamic>);
      } else {
        // Create user document in the selected role-based collection
        final newUser = UserModel(
          id: uid,
          name: displayName ?? email.split('@').first,
          email: email,
          role: selectedRole,
        );
        try {
          await _db.collection(collection).doc(uid).set(newUser.toJson()).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Writing profile to Firestore timed out.'),
          );
        } catch (e) {
          throw Exception('Failed to save profile to Firestore:\n$e');
        }
        _currentUser = newUser;
      }

      await fetchStudents();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _currentUser = null;
    notifyListeners();
  }
}
