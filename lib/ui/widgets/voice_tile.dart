import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../../state/voice_player.dart';
import '../theme.dart';

/// Một câu thoại: tiêu đề, lời thoại, nút phát.
class VoiceTile extends StatelessWidget {
  const VoiceTile({super.key, required this.voice});

  final Voice voice;

  @override
  Widget build(BuildContext context) {
    final player = VoicePlayer.instance;
    final scale = AppScope.of(context).textScale;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final playing = player.isPlaying(voice.url);
        final loading = player.isLoading(voice.url);
        final active = playing || loading;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.10) : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.accent.withValues(alpha: 0.6) : AppColors.line.withValues(alpha: 0.6)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: voice.url.isEmpty
                ? null
                : () async {
                    final ok = await player.toggle(voice.url);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.s.t('voice_error'))),
                      );
                    }
                  },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: voice.url.isEmpty
                        ? const Icon(Icons.subtitles_outlined, color: AppColors.textFaint)
                        : loading
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color: playing ? AppColors.accent : AppColors.cardHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                  color: playing ? Colors.white : AppColors.accent,
                                ),
                              ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voice.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: active ? AppColors.accent : AppColors.textDim,
                          ),
                        ),
                        if (voice.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(voice.text, style: TextStyle(fontSize: 14.5 * scale, height: 1.5)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
