import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'The OG members of The Lift League love to life, but we needed a little extra motivation while cooped up in our homes in 2020. So we added a scoring system to our workouts. It wasnt long before a little friendly competititon turned into The Lift League. Our goal is to foster sustainable motivation, promote healthy competition and provide clients with an affordable, high-quality trianing program that encourages beginners and esxperienced weightlifters alike to mainke resistance training an integral part of their lives.',
        ),
      ),
    );
  }
}
