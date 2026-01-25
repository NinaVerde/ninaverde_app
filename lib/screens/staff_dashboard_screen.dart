import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift_model.dart';
import 'package:intl/intl.dart';
import '../models/shift_model.dart';
import '../models/time_log_model.dart';
import '../services/schedule_service.dart';
import '../services/time_attendance_service.dart';
import '../services/user_profile_service.dart'; // Added
import '../widgets/nv_widgets.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
        return const Scaffold(body: Center(child: Text('Not logged in')));
    }
  
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const NvAppBar(
        title: 'My Work',
        extraActions: [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Clock In/Out Section (Hero)
            _buildClockSection(),
            const SizedBox(height: 24),
            
            // 1.5 Gamification (Elite)
            _buildReliabilityCard(),
            const SizedBox(height: 24),
            
            // 2. Earnings (Elite Feature)
            _buildEarningsCard(),
            const SizedBox(height: 24),

            // 3. Next Shift
            const Text('Next Shift', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildNextShiftCard(),
             const SizedBox(height: 24),

            // 3. Upcoming
            const Text('Upcoming Schedule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildUpcomingList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildClockSection() {
      return StreamBuilder<TimeLogModel?>(
          stream: TimeAttendanceService.getCurrentActiveLog(_userId),
          builder: (context, snapshot) {
              final activeLog = snapshot.data;
              final isClockedIn = activeLog != null;
              
              return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: isClockedIn 
                            ? [Colors.orange.shade900, Colors.deepOrange]
                            : [const Color(0xFF006400), const Color(0xFF00FF94)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                          BoxShadow(
                              color: isClockedIn ? Colors.orange.withOpacity(0.4) : const Color(0xFF00FF94).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                          )
                      ],
                  ),
                  child: Column(
                      children: [
                          Icon(
                              isClockedIn ? Icons.timer : Icons.storefront,
                              size: 48,
                              color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                              isClockedIn ? 'YOU ARE CLOCKED IN' : 'READY TO WORK?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                              ),
                          ),
                          if (isClockedIn) ...[
                              const SizedBox(height: 8),
                              Text(
                                  'Started at ${DateFormat('h:mm a').format(activeLog.clockInTime)}',
                                  style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              _LiveTimer(startTime: activeLog.clockInTime),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                  onPressed: _processing ? null : () => _handleClockAction(isClockedIn, activeLog?.id),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _processing 
                                    ? const CircularProgressIndicator()
                                    : Text(
                                      isClockedIn ? 'CLOCK OUT' : 'CLOCK IN',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                              ),
                          ),
                      ],
                  ),
              );
          },
      );
  }
  
  Widget _buildNextShiftCard() {
      // Reuse upcoming stream but take first
      return StreamBuilder<List<ShiftModel>>(
          stream: ScheduleService.getUpcomingShiftsForUser(_userId),
          builder: (context, snapshot) {
              final shifts = snapshot.data ?? [];
              if (shifts.isEmpty) {
                  return Card(
                      color: Colors.grey[900],
                      child: const ListTile(
                          title: Text('No upcoming shifts', style: TextStyle(color: Colors.white)),
                      ),
                  );
              }
              final next = shifts.first;
              return _ShiftCard(shift: next, isNext: true);
          },
      );
  }
  
  Widget _buildUpcomingList() {
      return StreamBuilder<List<ShiftModel>>(
          stream: ScheduleService.getUpcomingShiftsForUser(_userId),
          builder: (context, snapshot) {
               if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
               final shifts = snapshot.data ?? [];
               if (shifts.isEmpty) return const Text('No shifts found.', style: TextStyle(color: Colors.grey));
               
               // Skip first if it's displayed in "Next Shift" (optional, but cleaner)
               final list = shifts.length > 1 ? shifts.sublist(1) : <ShiftModel>[];
               
               if (list.isEmpty) return const SizedBox.shrink();
               
               return Column(
                   children: list.map((s) => _ShiftCard(shift: s)).toList(),
               );
          },
      );
  }
  
  Widget _buildEarningsCard() {
      // Fetch user profile for hourly rate
      return FutureBuilder(
          future: UserProfileService().getUserProfile(_userId),
          builder: (context, snapshot) {
              final user = snapshot.data;
              final rate = user?.hourlyRate ?? 0.0;
              
              // Calculate weekly earnings (Mock logic for now, or fetch logs)
              // Ideally: fetch logs for this week, sum hours * rate
              // For "Elite" visual, we'll just show the rate and a placeholder for "This Week"
              
              return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                          _StatItem(
                              label: 'HOURLY RATE',
                              value: '\$${rate.toStringAsFixed(2)}',
                              icon: Icons.monetization_on,
                              color: Colors.greenAccent,
                          ),
                          Container(width: 1, height: 40, color: Colors.grey[700]),
                          const _StatItem(
                              label: 'THIS WEEK',
                              value: '12.5 hrs', // Placeholder
                              icon: Icons.access_time,
                              color: Colors.blueAccent,
                          ),
                          Container(width: 1, height: 40, color: Colors.grey[700]),
                          _StatItem(
                              label: 'EST. PAY',
                              value: '\$${(12.5 * rate).toStringAsFixed(2)}', // Placeholder calculation
                              icon: Icons.account_balance_wallet,
                              color: Colors.amberAccent,
                          ),
                      ],
                  ),
              );
          },
      );
  }

  Widget _buildReliabilityCard() {
      // Mock Data for "Elite" feel
      const int streak = 12;
      const String level = "Reliable Pro";
      const double progress = 0.8; 
      
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.purple.shade900, Colors.deepPurple.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                  BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
          ),
          child: Row(
              children: [
                  // Badge / Icon
                  Container(
                      width: 60, height: 60,
                      decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.military_tech, color: Colors.amber, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              const Text("RELIABILITY SCORE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                              const SizedBox(height: 4),
                              const Text(level, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                  children: [
                                      const Icon(Icons.bolt, color: Colors.amber, size: 14),
                                      Text("$streak Shift Streak!", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                  ],
                              ),
                          ],
                      ),
                  ),
                  // Progress Ring
                  SizedBox(
                      width: 50, height: 50,
                      child: Stack(
                          fit: StackFit.expand,
                          children: [
                              CircularProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.black26,
                                  color: Colors.white,
                                  strokeWidth: 5,
                              ),
                              Center(child: Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                          ],
                      ),
                  ),
              ],
          ),
      );
  }

  Future<void> _handleClockAction(bool isClockedIn, String? logId) async {
      setState(() => _processing = true);
      try {
          // Verify Location Mock
          final inRange = await TimeAttendanceService.isWithinRange();
          if (!inRange) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are too far from Nina Verde!')));
               return;
          }
          
          if (isClockedIn && logId != null) {
              await TimeAttendanceService.clockOut(logId);
          } else {
              // Try to link to a shift?
              // Simple logic: Find shift starting within 2 hours +/-
              // For now null shiftId is fine
              await TimeAttendanceService.clockIn(_userId);
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
          if (mounted) setState(() => _processing = false);
      }
  }
}

class _LiveTimer extends StatefulWidget {
    final DateTime startTime;
    const _LiveTimer({required this.startTime});
    @override
    State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer> with SingleTickerProviderStateMixin {
    late final AnimationController _ctrl;
    
    @override
    void initState() {
        super.initState();
        _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    }
    
    @override
    void dispose() {
        _ctrl.dispose();
        super.dispose();
    }
    
    @override
    Widget build(BuildContext context) {
        return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
                final diff = DateTime.now().difference(widget.startTime);
                final h = diff.inHours;
                final m = diff.inMinutes % 60;
                final s = diff.inSeconds % 60;
                return Text(
                    '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontFeatures: [FontFeature.tabularFigures()]),
                );
            }
        );
    }
}

class _ShiftCard extends StatelessWidget {
    final ShiftModel shift;
    final bool isNext;
    
    const _ShiftCard({required this.shift, this.isNext = false});
    
    @override
    Widget build(BuildContext context) {
        final dateFmt = DateFormat('EEE, MMM d');
        final timeFmt = DateFormat('h:mm a');
        
        return Card(
            color: Colors.grey[900],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isNext ? const BorderSide(color: Color(0xFF00FF94)) : BorderSide.none,
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                    children: [
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                                children: [
                                    Text(DateFormat('MMM').format(shift.startTime).toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text(DateFormat('d').format(shift.startTime), style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                            ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        '${timeFmt.format(shift.startTime)} - ${timeFmt.format(shift.endTime)}',
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                        shift.role.name.toUpperCase(),
                                        style: TextStyle(color: shift.color ?? const Color(0xFF00FF94), fontSize: 12),
                                    ),
                                    if (shift.notes != null && shift.notes!.isNotEmpty)
                                        Text(
                                            shift.notes!,
                                            style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                                        ),
                                ],
                            ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.swap_horiz, color: Colors.grey),
                            onPressed: () {
                                // TODO: Implement Swap Request
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Swap request coming soon')));
                            },
                        ),
                    ],
                ),
            ),
        );
    }
}

class _StatItem extends StatelessWidget {
    final String label;
    final String value;
    final IconData icon;
    final Color color;
    
    const _StatItem({required this.label, required this.value, required this.icon, required this.color});
    
    @override
    Widget build(BuildContext context) {
        return Column(
            children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
        );
    }
}
