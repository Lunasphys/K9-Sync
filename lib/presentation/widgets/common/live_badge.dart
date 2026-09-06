import 'package:flutter/material.dart';

import 'package:k9sync/core/theme/app_theme.dart';

/// Small connection-state pill (dot + label), pulsing gently while
/// [connected] to reinforce the feeling of a live, continuous data stream.
/// The dot goes still as soon as the connection drops.
class LiveBadge extends StatefulWidget {
  final bool connected;
  final String liveLabel;
  final String offlineLabel;

  const LiveBadge({
    super.key,
    required this.connected,
    this.liveLabel = 'Live',
    this.offlineLabel = 'Off',
  });

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.connected) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant LiveBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected && !oldWidget.connected) {
      _controller.repeat(reverse: true);
    } else if (!widget.connected && oldWidget.connected) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.connected ? AppColors.greenMint : Colors.grey.shade200,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(opacity: _pulse, child: _dot()),
          const SizedBox(width: 5),
          Text(
            widget.connected ? widget.liveLabel : widget.offlineLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: widget.connected ? AppColors.greenStatus : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: widget.connected ? AppColors.greenStatus : Colors.grey,
      shape: BoxShape.circle,
    ),
  );
}
