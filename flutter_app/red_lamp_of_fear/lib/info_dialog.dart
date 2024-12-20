
import 'package:flutter/material.dart';

class InfoDialog extends StatelessWidget {
  const InfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text('Information:', style: TextStyle(fontSize: 16, decoration: TextDecoration.underline)),
                    const SizedBox(height: 15),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            style: TextStyle(color: Colors.black),
                            text: "This Mobile Application is made by tortik92 for use in HTL Donaustadt. Please use this app wisely.\n\n"
                          ),
                          TextSpan(
                            style: TextStyle(color: Colors.blueAccent),
                            text: "https://github.com/tortik92/Lamp-Of-Fear-Red/",
                          )
                        ]
                    )),
                    const SizedBox(height: 15),
                    const Text("Cakelab Studio 2024", textAlign: TextAlign.center,)
                  ],
                ),
              ),
            );
  }
}