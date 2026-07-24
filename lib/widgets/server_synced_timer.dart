import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ServerSyncedTimer extends StatefulWidget {
  final String roomId;
  final bool isHost;
  final VoidCallback? onTimerEnded;

  const ServerSyncedTimer({
    Key? key,
    required this.roomId,
    this.isHost = false,
    this.onTimerEnded,
  }) : super(key: key);

  @override
  _ServerSyncedTimerState createState() => _ServerSyncedTimerState();
}

class _ServerSyncedTimerState extends State<ServerSyncedTimer> {
  Timer? _uiTimer;
  int _remainingSeconds = 0;
  DateTime? _endTime;
  bool _hasTriggeredEnd = false;

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  void _startUITimer() {
    _uiTimer?.cancel();
    _hasTriggeredEnd = false;
    
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_endTime != null) {
        final now = DateTime.now();
        final diff = _endTime!.difference(now).inSeconds;

        if (diff >= 0) {
          if (mounted) {
            setState(() {
              _remainingSeconds = diff;
            });
          }
        } else {
          _uiTimer?.cancel();
          if (mounted) {
            setState(() {
              _remainingSeconds = 0;
            });
          }
          
          if (widget.isHost && !_hasTriggeredEnd) {
            _hasTriggeredEnd = true;
            if (widget.onTimerEnded != null) {
              widget.onTimerEnded!();
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      // DÜZELTİLDİ: 'rooms' yerine 'games' koleksiyonu dinleniyor
      stream: FirebaseFirestore.instance.collection('games').doc(widget.roomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        
        var startTime = data['phaseStartTime'] as Timestamp?;
        var duration = data['phaseDuration'] as int? ?? 0;

        if (startTime == null) {
          return const Text(
            "Bekleniyor...",
            style: TextStyle(color: Colors.white70, fontSize: 20),
          );
        }

        DateTime calculatedEndTime = startTime.toDate().add(Duration(seconds: duration));
        
        if (_endTime != calculatedEndTime) {
          _endTime = calculatedEndTime;
          _startUITimer();
        }

        Color timerColor = _remainingSeconds <= 10 ? Colors.redAccent : Colors.white;

        return Text(
          _remainingSeconds.toString(),
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: timerColor,
          ),
        );
      },
    );
  }
}