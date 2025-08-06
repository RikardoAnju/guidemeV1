import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'Login.dart';

class CountryCodePicker extends StatefulWidget {
  final Function(String) onCodeChanged;

  const CountryCodePicker({super.key, required this.onCodeChanged});

  @override
  CountryCodePickerState createState() => CountryCodePickerState();
}

class CountryCodePickerState extends State<CountryCodePicker> {
  List<Map<String, String>> countryCodes = [];
  String? selectedCode;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCountryCodes();
  }

  Future<void> fetchCountryCodes() async {
    try {
      final url = Uri.parse("https://restcountries.com/v3.1/all?fields=name,idd");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Map<String, String>> fetchedCountries = [];

        for (var country in data) {
          if (country["idd"] != null && country["idd"]["root"] != null) {
            String root = country["idd"]["root"] ?? "";
            List<String>? suffixes = country["idd"]["suffixes"]?.cast<String>();

            root = root.startsWith("+") ? root : "+$root";
            String code =
                suffixes != null && suffixes.isNotEmpty
                    ? root + suffixes.join("")
                    : root;

            String countryName = country["name"]?["common"] ?? "Unknown";

            if (code.isNotEmpty) {
              fetchedCountries.add({"code": code, "country": countryName});
            }
          }
        }

        fetchedCountries.sort((a, b) => a["country"]!.compareTo(b["country"]!));

        setState(() {
          countryCodes = fetchedCountries;
          selectedCode =
              countryCodes.isNotEmpty ? countryCodes[0]["code"] : null;
          widget.onCodeChanged(selectedCode ?? "");
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load country codes");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Error fetching country codes: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(selectedCode),
            isExpanded: true,
            value: selectedCode ?? countryCodes.firstOrNull?["code"],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10),
            ),
            items:
                countryCodes.map((country) {
                  return DropdownMenuItem<String>(
                    value: country["code"],
                    child: Text("${country["country"]} (${country["code"]})"),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCode = value;
              });
              widget.onCodeChanged(selectedCode ?? "");
            },
          ),
        );
  }
}

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  RegisterState createState() => RegisterState();
}

class RegisterState extends State<Register> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? selectedGender;
  List<String> genderOptions = ["Male", "Female"];

  bool _isLoading = false;
  String? _selectedCode;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  bool isValidPassword(String password) {
    String pattern = r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$';
    RegExp regExp = RegExp(pattern);
    return regExp.hasMatch(password);
  }

  Future<void> _registerUser() async {
  List<String> errors = [];

  if (_firstNameController.text.isEmpty) errors.add('First Name harus diisi');
  if (_lastNameController.text.isEmpty) errors.add('Last Name harus diisi');
  if (_emailController.text.isEmpty) errors.add('Email harus diisi');
  if (_usernameController.text.isEmpty) errors.add('Username harus diisi');
  if (_phoneNumberController.text.isEmpty) errors.add('Nomor telepon harus diisi');
  if (_passwordController.text.isEmpty) errors.add('Password harus diisi');
  if (_confirmPasswordController.text.isEmpty) errors.add('Konfirmasi password harus diisi');
  if (_selectedCode == null) errors.add('Kode negara harus dipilih');
  if (_addressController.text.isEmpty) errors.add('Alamat harus diisi');
  if (selectedGender == null) errors.add('Jenis kelamin harus dipilih');

  if (errors.isNotEmpty) {
    _showErrorDialog(errors);
    return;
  }

  if (!isValidPassword(_passwordController.text)) {
    _showErrorDialog([
      'Password minimal 8 karakter, mengandung huruf besar, huruf kecil, dan angka',
    ]);
    return;
  }

  if (_passwordController.text != _confirmPasswordController.text) {
    _showErrorDialog(['Password tidak cocok']);
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    var emailCheck = await _firestore
        .collection('users')
        .where('email', isEqualTo: _emailController.text.trim())
        .get();

    if (emailCheck.docs.isNotEmpty) {
      _showWarningDialog('Email sudah terdaftar, silakan gunakan email lain.');
      setState(() => _isLoading = false);
      return;
    }

    var usernameCheck = await _firestore
        .collection('users')
        .where('username', isEqualTo: _usernameController.text.trim())
        .get();

    if (usernameCheck.docs.isNotEmpty) {
      _showWarningDialog('Username telah digunakan, silakan pilih username lain');
      setState(() => _isLoading = false);
      return;
    }

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    await userCredential.user!.sendEmailVerification();

    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'id': userCredential.user!.uid,
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': "$_selectedCode${_phoneNumberController.text.trim()}",
      'gender': selectedGender,
      'address': _addressController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'user',
      'emailVerified': false,
    });

    _showSuccessDialog("Email verifikasi telah dikirim. Silakan cek email Anda.");

    _showSuccessDialog("Email verifikasi telah dikirim. Silakan cek email Anda.");

// Reset form setelah sukses
_firstNameController.clear();
_lastNameController.clear();
_emailController.clear();
_usernameController.clear();
_phoneNumberController.clear();
_passwordController.clear();
_confirmPasswordController.clear();
_addressController.clear();
setState(() {
  selectedGender = null;
  _selectedCode = null;
});

  } on FirebaseAuthException catch (e) {
    String errorMessage = 'Registrasi gagal';
    if (e.code == 'weak-password') {
      errorMessage = 'Password terlalu lemah';
    } else if (e.code == 'email-already-in-use') {
      errorMessage = 'Email sudah terdaftar';
    }
    _showErrorDialog([errorMessage]);
  } catch (e) {
    _showErrorDialog(['Registrasi gagal: ${e.toString()}']);
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

void _showSuccessDialog(String message) {
  showDialog(
    context: context,
    barrierDismissible: false, // Modal tidak bisa ditutup dengan klik di luar
    builder: (context) {
      return AlertDialog(
        title: const Text(
          'Sukses!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); 
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              ); 
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

  void _showErrorDialog(List<String> messages) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Terjadi Kesalahan',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: messages.map((msg) => Text('- $msg')).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Peringatan!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 250,
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 100),
                const Text(
                  "CREATE ACCOUNT",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: "First Name",
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: "Last Name",
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: "Username",
                            prefixIcon: Icon(Icons.account_circle),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            CountryCodePicker(
                              onCodeChanged: (code) {
                                setState(() {
                                  _selectedCode = code;
                                });
                              },
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _phoneNumberController,
                                decoration: const InputDecoration(
                                  labelText: "Phone Number",
                                  prefixIcon: Icon(Icons.phone),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Password",
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Confirm Password",
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: "Address",
                            prefixIcon: Icon(Icons.home),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value:
                              selectedGender,
                          decoration: const InputDecoration(
                            labelText: "Gender",
                            prefixIcon: Icon(Icons.wc),
                            border: OutlineInputBorder(),
                          ),
                          items:
                              genderOptions.map((gender) {
                                return DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                          onChanged: (newValue) {
                            selectedGender = newValue;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _registerUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child:
                                _isLoading
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : const Text(
                                      "REGISTER",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Already have an account? Login here",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: Register()),
  );
}