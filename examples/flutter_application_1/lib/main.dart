//Standard packages
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

//Speech Recognition packages
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

//Application detection packages
//import 'package:installed_apps/installed_apps.dart'; //App checking
import 'package:device_apps/device_apps.dart'; //App checking

//------------------------------------SECTION 1----------------------
//-------------------SPEECH TO TEXT CODE -----------------------

void main() => runApp(const SpeechSampleApp());

class SpeechSampleApp extends StatefulWidget {
  const SpeechSampleApp({super.key});

  @override
  State<SpeechSampleApp> createState() => _SpeechSampleAppState();
}

/// An example that demonstrates the basic functionality of the
/// SpeechToText plugin for using the speech recognition capability
/// of the underlying platform.
class _SpeechSampleAppState extends State<SpeechSampleApp> {
  bool _hasSpeech = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '';

String targetWord = 'ngiyala';

List<String> targetSegments = [
  'ngi',
  'ya',
  'la',
];

String recognizedText = '';
String rawSttResult = '';
String closestSttCandidate = '';

String acousticStatus = '';
double? acousticSimilarity;
double? acousticNormalizedDistance;
double? acousticDtwDistance;

String teacherSttResult = '';
String learnerSttResult = '';
double? sttSimilarity;

final AudioPlayer teacherAudioPlayer = AudioPlayer();
final AudioPlayer learnerAudioPlayer = AudioPlayer();

String selectedTeacherUrl =
    'https://prt820-language-app1.s3.ap-southeast-2.amazonaws.com/words/Common/ngiyala.wav';

final AudioRecorder learnerRecorder = AudioRecorder();

bool isLearnerRecording = false;
String? learnerRecordingPath;

List<double> segmentScores = [
  0.0,
  0.0,
  0.0,
];

String overallResult = '';

  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();

  SpeechExampleConfig currentOptions = SpeechExampleConfig(
    SpeechListenOptions(
      listenMode: ListenMode.confirmation,
      onDevice: false,
      cancelOnError: true,
      partialResults: true,
      autoPunctuation: true,
      enableHapticFeedback: true,
    ),
    "",
    3,
    30,
    false,
    false,
  );

  @override
  void initState() {
    super.initState();
  }

  /// This initializes SpeechToText. That only has to be done
  /// once per application, though calling it again is harmless
  /// it also does nothing. The UX of the sample app ensures that
  /// it can only be called once.
  Future<void> initSpeechState() async {
    _logEvent('Initialize');
    try {
      var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: currentOptions.debugLogging,
      );
      if (hasSpeech) {
        //FIXME - not defined Use normal aggregation
        //speech.unexpectedPhraseAggregator = _punctAggregator;

        // Get the list of languages installed on the supporting platform so they
        // can be displayed in the UI for selection by the user.
        _localeNames = await speech.locales();

        var systemLocale = await speech.systemLocale();
        currentOptions = currentOptions.copyWith(
          localeId: systemLocale?.localeId ?? '',
        );
      }
      if (!mounted) return;

      setState(() {
        _hasSpeech = hasSpeech;
      });
    } catch (e) {
      setState(() {
        lastError = 'Speech recognition failed: ${e.toString()}';
        _hasSpeech = false;
      });
    }
  }

  String _punctAggregator(List<String> phrases) {
    return phrases.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Pronunciation Analysis Prototype'),
      ),
        body: Builder(
          builder: (ctx) => SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InitSpeechWidget(_hasSpeech, initSpeechState),
                    ),
                    TextButton.icon(
                      // key: ,
                      onPressed: () async {
                        currentOptions = await showSetUp(
                          ctx,
                          currentOptions,
                          _localeNames,
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Session Options'),
                    ),
                  ],
                ),
                
                RecognitionResultsWidget(
  lastWords: lastWords,
  level: level,
  targetWord: targetWord,
  targetSegments: targetSegments,
  segmentScores: segmentScores,
  overallResult: overallResult,
  rawSttResult: rawSttResult,
  closestSttCandidate: closestSttCandidate,
),
const SizedBox(height: 16),

const Text(
  'LEARNER PRONUNCIATION ATTEMPT',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 10),

Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    ElevatedButton.icon(
      onPressed:
          isLearnerRecording ? null : startLearnerAttempt,
      icon: const Icon(Icons.mic),
      label: const Text('Start Learner Attempt'),
    ),

    const SizedBox(width: 12),

    ElevatedButton.icon(
      onPressed:
          isLearnerRecording ? stopLearnerAttempt : null,
      icon: const Icon(Icons.stop),
      label: const Text('Stop Attempt'),
    ),
  ],
),

const SizedBox(height: 8),

if (isLearnerRecording)
  const Text(
    'Recording...',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),

if (!isLearnerRecording && learnerRecordingPath != null)
  const Text(
    'Learner recording ready ✓',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  const SizedBox(height: 10),

Wrap(
  alignment: WrapAlignment.center,
  spacing: 12,
  runSpacing: 8,
  children: [
    ElevatedButton.icon(
      onPressed: playTeacherAudio,
      icon: const Icon(Icons.volume_up),
      label: const Text('Listen to Teacher'),
    ),

    ElevatedButton.icon(
      onPressed:
          learnerRecordingPath == null
              ? null
              : playLearnerAudio,
      icon: const Icon(Icons.play_arrow),
      label: const Text('Listen to My Recording'),
    ),
  ],
),

const SizedBox(height: 10),

ElevatedButton.icon(
  onPressed: runAcousticCheck,
  icon: const Icon(Icons.graphic_eq),
  label: const Text('Analyse Pronunciation'),
),

const SizedBox(height: 10),

if (acousticStatus.isNotEmpty)
  Text(
    acousticStatus,
    textAlign: TextAlign.center,
  ),
// =====================================================
// TEACHER VS LEARNER STT
// =====================================================

if (teacherSttResult.isNotEmpty ||
    learnerSttResult.isNotEmpty) ...[

  const SizedBox(height: 16),

  const Text(
    'SPEECH RECOGNITION COMPARISON',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  ),

  const SizedBox(height: 8),

  Text(
    'Teacher STT: '
    '${teacherSttResult.isEmpty ? "-" : teacherSttResult}',
  ),

  const SizedBox(height: 4),

  Text(
    'Learner STT: '
    '${learnerSttResult.isEmpty ? "-" : learnerSttResult}',
  ),

  const SizedBox(height: 4),

  if (sttSimilarity != null)
    Text(
      'STT similarity: '
      '${(sttSimilarity! * 100).toStringAsFixed(1)}%',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
],

const SizedBox(height: 10),

if (acousticSimilarity != null)
  Text(
    'Acoustic similarity: '
    '${(acousticSimilarity! * 100).toStringAsFixed(1)}%',
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),

if (acousticNormalizedDistance != null)
  Text(
    'Normalized DTW distance: '
    '${acousticNormalizedDistance!.toStringAsFixed(3)}',
  ),

              SpeechStatusWidget(lastStatus: lastStatus),
              ErrorWidget(lastError: lastError),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // This is called each time the users wants to start a new speech
  // recognition session
  void startListening() {
    _logEvent('start listening');
    lastWords = '';
    lastError = '';
    // Note that `listenFor` is the maximum, not the minimum, on some
    // systems recognition will be stopped before this value is reached.
    // Similarly `pauseFor` is a maximum not a minimum and may be ignored
    // on some devices.
    speech.listen(
      onResult: resultListener,
      listenFor: Duration(seconds: currentOptions.listenFor),
      pauseFor: Duration(seconds: currentOptions.pauseFor),
      localeId: currentOptions.localeId,
      onSoundLevelChange: soundLevelListener,
      listenOptions: currentOptions.options,
    );
    setState(() {});
  }

  void stopListening() {
    _logEvent('stop');
    speech.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    _logEvent('cancel');
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }
Future<void> startLearnerAttempt() async {
  await startLearnerRecording();

  if (!isLearnerRecording) {
    return;
  }

  setState(() {
    acousticStatus = 'Recording learner pronunciation...';
  });
}
  Future<void> startLearnerRecording() async {
  try {
    final hasPermission = await learnerRecorder.hasPermission();

    if (!hasPermission) {
      setState(() {
        acousticStatus = 'Microphone permission was not granted.';
      });
      return;
    }

    await learnerRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: '',
    );

    setState(() {
      isLearnerRecording = true;
      learnerRecordingPath = null;
      acousticStatus = 'Recording learner attempt...';
    });
  } catch (e) {
    setState(() {
      acousticStatus = 'Could not start learner recording: $e';
    });
  }
}

Future<void> stopLearnerRecording() async {
  try {
    final path = await learnerRecorder.stop();

    setState(() {
      isLearnerRecording = false;
      learnerRecordingPath = path;

      if (path == null) {
        acousticStatus = 'No learner recording was captured.';
      } else {
        acousticStatus = 'Learner recording captured.';
      }
    });

    debugPrint('LEARNER RECORDING PATH: $path');
  } catch (e) {
    setState(() {
      isLearnerRecording = false;
      acousticStatus = 'Could not stop learner recording: $e';
    });
  }
}
Future<void> stopLearnerAttempt() async {
  if (speech.isListening) {
    await speech.stop();
  }

  if (isLearnerRecording) {
    await stopLearnerRecording();
  }

  setState(() {
    level = 0.0;
  });
}
Future<void> playTeacherAudio() async {
  try {
    await teacherAudioPlayer.stop();

    await teacherAudioPlayer.play(
      UrlSource(selectedTeacherUrl),
    );
  } catch (e) {
    setState(() {
      acousticStatus = 'Could not play teacher audio: $e';
    });
  }
}

Future<void> playLearnerAudio() async {
  if (learnerRecordingPath == null) {
    setState(() {
      acousticStatus = 'Record your pronunciation first.';
    });
    return;
  }

  try {
    await learnerAudioPlayer.stop();

    await learnerAudioPlayer.play(
      UrlSource(learnerRecordingPath!),
    );
  } catch (e) {
    setState(() {
      acousticStatus = 'Could not play learner audio: $e';
    });
  }
}
  Future<void> runAcousticCheck() async {
  final teacherUrl = selectedTeacherUrl;

  if (learnerRecordingPath == null) {
    setState(() {
      acousticStatus = 'Please record a learner attempt first.';
    });
    return;
  }

  setState(() {
    acousticStatus = 'Uploading and analysing learner recording...';
    acousticSimilarity = null;
    acousticNormalizedDistance = null;
    acousticDtwDistance = null;
  });

  try {
    // Get the WAV bytes from the browser recording
    final recordedAudioResponse =
        await http.get(Uri.parse(learnerRecordingPath!));

    if (recordedAudioResponse.statusCode != 200) {
      setState(() {
        acousticStatus = 'Could not read learner recording.';
      });
      return;
    }

    // Send teacher URL + actual learner WAV to Flask
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:8081/compare-upload'),
    );

    request.fields['teacher_url'] = teacherUrl;

    request.files.add(
      http.MultipartFile.fromBytes(
        'learner_audio',
        recordedAudioResponse.bodyBytes,
        filename: 'learner_attempt.wav',
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  final backendTeacherStt =
    (data['teacher_stt'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

final backendLearnerStt =
    (data['learner_stt'] ?? data['stt_text'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

final backendSttSimilarity =
    (data['stt_similarity'] as num?)?.toDouble();

  final backendStt = backendLearnerStt;

final acousticSegmentsRaw =
    (data['acoustic_segments'] as List<dynamic>?) ?? [];

final acousticByLabel = <String, double>{};

for (final item in acousticSegmentsRaw) {
  final segment =
      Map<String, dynamic>.from(item as Map);

  final label =
      (segment['label'] ?? '')
          .toString()
          .toLowerCase();

  final similarity =
      (segment['similarity'] as num?)
              ?.toDouble() ??
          0.0;

  acousticByLabel[label] =
      similarity.clamp(0.0, 1.0).toDouble();
}

final acousticSegmentScores = targetSegments
    .map(
      (segment) =>
          acousticByLabel[
              segment.toLowerCase()] ??
          0.0,
    )
    .toList();

String backendResultMessage = '';

if (acousticSegmentScores.isNotEmpty) {
  int weakestIndex = 0;

  for (int i = 1; i < acousticSegmentScores.length; i++) {
    if (acousticSegmentScores[i] <
        acousticSegmentScores[weakestIndex]) {
      weakestIndex = i;
    }
  }

  backendResultMessage =
      'Lowest-similarity segment: '
      '${targetSegments[weakestIndex].toUpperCase()}';
}

setState(() {
  // NEW: save teacher + learner STT results
  teacherSttResult = backendTeacherStt;
  learnerSttResult = backendLearnerStt;
  sttSimilarity = backendSttSimilarity;

  // Existing acoustic results
  acousticSimilarity =
      (data['similarity'] as num?)?.toDouble();

  acousticNormalizedDistance =
      (data['normalized_distance'] as num?)?.toDouble();

  acousticDtwDistance =
      (data['dtw_distance'] as num?)?.toDouble();

  // Keep existing learner STT behaviour
  rawSttResult = backendStt;
  closestSttCandidate = backendStt;
  recognizedText = backendStt;
  lastWords = backendStt;

  // Keep DTW segment results
  segmentScores = acousticSegmentScores;
  overallResult = backendResultMessage;

  acousticStatus =
      'Combined speech and acoustic analysis completed.';
});
}
else {
  setState(() {
    acousticStatus =
        'Combined analysis failed: ${response.statusCode} ${response.body}';
  });
}
} catch (e) {
  setState(() {
    acousticStatus = 'Combined analysis error: $e';
  });
}
}
  List<double> calculateSegmentScores(
  List<String> segments,
  String detected,
) {
  final target = segments.join().toLowerCase();
  final spoken = detected
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), '');

  if (target.isEmpty || spoken.isEmpty) {
    return List<double>.filled(segments.length, 0.0);
  }

  final rows = target.length + 1;
  final cols = spoken.length + 1;

  final dp = List.generate(
    rows,
    (_) => List<int>.filled(cols, 0),
  );

  for (int i = 0; i < rows; i++) {
    dp[i][0] = i;
  }

  for (int j = 0; j < cols; j++) {
    dp[0][j] = j;
  }

  for (int i = 1; i < rows; i++) {
    for (int j = 1; j < cols; j++) {
      final cost =
          target[i - 1] == spoken[j - 1] ? 0 : 1;

      dp[i][j] = min(
        min(
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
        ),
        dp[i - 1][j - 1] + cost,
      );
    }
  }

  final matchedCharacters =
      List<bool>.filled(target.length, false);

  int i = target.length;
  int j = spoken.length;

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0) {
      final cost =
          target[i - 1] == spoken[j - 1] ? 0 : 1;

      if (dp[i][j] ==
          dp[i - 1][j - 1] + cost) {
        if (cost == 0) {
          matchedCharacters[i - 1] = true;
        }

        i--;
        j--;
        continue;
      }
    }

    if (i > 0 &&
        dp[i][j] == dp[i - 1][j] + 1) {
      i--;
      continue;
    }

    if (j > 0) {
      j--;
    }
  }

  final scores = <double>[];

  int startIndex = 0;

  for (final segment in segments) {
    int matches = 0;

    for (int k = 0; k < segment.length; k++) {
      if (matchedCharacters[startIndex + k]) {
        matches++;
      }
    }

    final score =
        segment.isEmpty ? 0.0 : matches / segment.length;

    scores.add(score);

    startIndex += segment.length;
  }

  return scores;
}
String findClosestSttCandidate(
  SpeechRecognitionResult result,
  String target,
) {
  if (result.alternates.isEmpty) {
    return result.recognizedWords.trim();
  }

  final cleanTarget =
      target.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  String bestCandidate =
      result.alternates.first.recognizedWords.trim();

  double bestScore = double.infinity;

  for (final alternative in result.alternates) {
    final candidate = alternative.recognizedWords.trim();

    if (candidate.isEmpty) {
      continue;
    }

    final cleanCandidate =
        candidate.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    final distance = levenshteinDistance(
      cleanTarget,
      cleanCandidate,
    );

    final longestLength = max(
      cleanTarget.length,
      cleanCandidate.length,
    );

    final normalizedDistance =
        longestLength == 0 ? 1.0 : distance / longestLength;

    if (normalizedDistance < bestScore) {
      bestScore = normalizedDistance;
      bestCandidate = candidate;
    }
  }

  return bestCandidate;
}

  
  /// This callback is invoked each time new recognition results are
  /// available after `listen` is called.
void resultListener(SpeechRecognitionResult result) {
  _logEvent(
    'Result listener final: ${result.finalResult}, '
    'words: ${result.recognizedWords}',
  );
  

  if (!result.finalResult) {
    return;
  }

  debugPrint('--- FINAL STT ALTERNATIVES ---');

  for (int i = 0; i < result.alternates.length; i++) {
    final alternative = result.alternates[i];

    debugPrint(
    '${i + 1}. ${alternative.recognizedWords} '
    '| confidence: ${alternative.confidence}',
    );
 }


  final rawDetected = result.recognizedWords.trim();

  final bestCandidate =
      findClosestSttCandidate(result, targetWord);

  final scores = calculateSegmentScores(
    targetSegments,
    bestCandidate,
  );

  int strongSegments = 0;

  for (final score in scores) {
    if (score >= 0.75) {
      strongSegments++;
    }
  }

  String resultMessage;

  if (strongSegments == targetSegments.length) {
    resultMessage =
        'All target segments were captured by speech recognition.';
  } else if (strongSegments > 0) {
    resultMessage =
        'Speech recognition captured some parts of the target.';
  } else {
    resultMessage =
        'Speech recognition did not capture the target well.';
  }

  setState(() {
  recognizedText = bestCandidate;
  rawSttResult = rawDetected;
  closestSttCandidate = bestCandidate;
  lastWords = bestCandidate;
  segmentScores = scores;
  overallResult = resultMessage;
});
}
void soundLevelListener(double level) {
  minSoundLevel = min(minSoundLevel, level);
  maxSoundLevel = max(maxSoundLevel, level);

  setState(() {
    this.level = level;
  });
}

void errorListener(SpeechRecognitionError error) {
  _logEvent(
    'Received error status: $error, listening: ${speech.isListening}',
  );

  setState(() {
    lastError = '${error.errorMsg} - ${error.permanent}';
  });
}

void statusListener(String status) {
  _logEvent(
    'Received listener status: $status, listening: ${speech.isListening}',
  );

  setState(() {
    lastStatus = status;
  });
}

  void _logEvent(String eventDescription) {
    if (currentOptions.logEvents) {
      var eventTime = DateTime.now().toIso8601String();
      debugPrint('$eventTime $eventDescription');
    }
  }
}

/// Displays the most recently recognized words and the sound level.
class RecognitionResultsWidget extends StatelessWidget {
  const RecognitionResultsWidget({
    super.key,
    required this.lastWords,
    required this.level,
    required this.targetWord,
    required this.targetSegments,
    required this.segmentScores,
    required this.overallResult,
    required this.rawSttResult,
    required this.closestSttCandidate,
  });

  final String lastWords;
  final double level;
  final String targetWord;
  final List<String> targetSegments;
  final List<double> segmentScores;
  final String overallResult;
  final String rawSttResult;
  final String closestSttCandidate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Center(
          child: Text(
            'Segment-Level Pronunciation Analysis',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        Stack(
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(minHeight: 320),
              color: Theme.of(context).secondaryHeaderColor,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'TARGET WORD',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      targetWord,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'ACOUSTIC SEGMENT FEEDBACK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        targetSegments.length,
                        (index) {
                          final score = index < segmentScores.length
                              ? segmentScores[index]
                              : 0.0;

                          final percentage = (score * 100).round();

                          String status;

                          if (score >= 0.75) {
                            status = 'Matched';
                          } else if (score > 0.0) {
                            status = 'Partial';
                          } else {
                            status = 'Missing';
                          }

                          return Expanded(
                            child: Column(
                              children: [
                                Text(
                                  targetSegments[index].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  '$percentage%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  status,
                                  style: const TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Divider(),

                    const SizedBox(height: 12),

                    const Text(
  'SPEECH-TO-TEXT TRANSCRIPTION',
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 6),

Text(
  rawSttResult.isEmpty ? '-' : rawSttResult,
  style: const TextStyle(
    fontSize: 22,
  ),
),

const SizedBox(height: 20),

if (overallResult.isNotEmpty)
  Text(
    overallResult,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            Positioned.fill(
              bottom: 10,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MicrophoneWidget(level: level),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
/// Display the current error status from the speech
/// recognizer
class ErrorWidget extends StatelessWidget {
  const ErrorWidget({super.key, required this.lastError});

  final String lastError;

  @override
  Widget build(BuildContext context) {
    return lastError.isNotEmpty
        ? Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Center(child: SelectableText(lastError)),
            ],
          )
        : const SizedBox();
  }
}

/// Controls to start and stop speech recognition
class SpeechControlWidget extends StatelessWidget {
  const SpeechControlWidget(
    this.hasSpeech,
    this.isListening,
    this.startListening,
    this.stopListening,
    this.cancelListening, {
    super.key,
  });

  final bool hasSpeech;
  final bool isListening;
  final void Function() startListening;
  final void Function() stopListening;
  final void Function() cancelListening;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        TextButton(
          onPressed: !hasSpeech || isListening ? null : startListening,
          child: const Text('Start'),
        ),
        TextButton(
          onPressed: isListening ? stopListening : null,
          child: const Text('Stop'),
        ),
        TextButton(
          onPressed: isListening ? cancelListening : null,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class SessionOptionsWidget extends StatelessWidget {
  const SessionOptionsWidget({
    required this.options,
    required this.localeNames,
    super.key,
    required this.onChange,
    required this.listenForController,
    required this.pauseForController,
  });

  final SpeechExampleConfig options;
  final List<LocaleName> localeNames;
  final void Function(SpeechExampleConfig newOptions) onChange;
  final TextEditingController listenForController;
  final TextEditingController pauseForController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: [
            const Text('localeId: '),
            Expanded(
              child: DropdownButton<String>(
                onChanged: (selectedVal) => onChange(
                  options.copyWith(localeId: selectedVal ?? options.localeId),
                ),
                value: options.localeId,
                isExpanded: true,
                items: localeNames
                    .map(
                      (localeName) => DropdownMenuItem(
                        value: localeName.localeId,
                        child: Text(localeName.name),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('pauseFor: '),
            Container(
              padding: const EdgeInsets.only(left: 8),
              width: 80,
              child: TextFormField(controller: pauseForController),
            ),
          ],
        ),
        Row(
          children: [
            const Text('listenFor: '),
            Container(
              padding: const EdgeInsets.only(left: 8),
              width: 80,
              child: TextFormField(controller: listenForController),
            ),
          ],
        ),
        Row(
          children: [
            const Text('partialResults: '),
            Checkbox(
              value: options.options.partialResults,
              onChanged: (value) {
                onChange(
                  options.copyWith(
                    options: options.options.copyWith(partialResults: value),
                  ),
                );
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('onDevice: '),
            Checkbox(
              value: options.options.onDevice,
              onChanged: (value) {
                onChange(
                  options.copyWith(
                    options: options.options.copyWith(onDevice: value),
                  ),
                );
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('cancelOnError: '),
            Checkbox(
              value: options.options.cancelOnError,
              onChanged: (value) {
                onChange(
                  options.copyWith(
                    options: options.options.copyWith(cancelOnError: value),
                  ),
                );
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('autoPunctuation: '),
            Checkbox(
              value: options.options.autoPunctuation,
              onChanged: (value) {
                onChange(
                  options.copyWith(
                    options: options.options.copyWith(autoPunctuation: value),
                  ),
                );
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('enableHapticFeedback: '),
            Checkbox(
              value: options.options.enableHapticFeedback,
              onChanged: (value) {
                onChange(
                  options.copyWith(
                    options: options.options.copyWith(
                      enableHapticFeedback: value,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        Row(
          children: [
            const Text('debugLogging: '),
            Checkbox(
              value: options.debugLogging,
              onChanged: (value) =>
                  onChange(options.copyWith(debugLogging: value)),
            ),
          ],
        ),
        Row(
          children: [
            const Text('Log events: '),
            Checkbox(
              value: options.logEvents,
              onChanged: (value) =>
                  onChange(options.copyWith(logEvents: value)),
            ),
          ],
        ),
      ],
    );
  }
}

class InitSpeechWidget extends StatelessWidget {
  const InitSpeechWidget(this.hasSpeech, this.initSpeechState, {super.key});

  final bool hasSpeech;
  final Future<void> Function() initSpeechState;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        OutlinedButton(
          onPressed: hasSpeech ? null : initSpeechState,
          child: const Text('Initialize'),
        ),
      ],
    );
  }
}

/// Display the current status of the listener
class SpeechStatusWidget extends StatelessWidget {
  const SpeechStatusWidget({super.key, required this.lastStatus});

  final String lastStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Status',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Center(child: SelectableText(lastStatus)),
      ],
    );
  }
}

/// A class that holds the configuration for the speech recognition
/// example app. This is used to pass the configuration to the
/// setup dialog and to hold the current configuration.
class SpeechExampleConfig {
  final SpeechListenOptions options;
  final String localeId;
  final bool logEvents;
  final bool debugLogging;
  final int pauseFor;
  final int listenFor;

  SpeechExampleConfig(
    this.options,
    this.localeId,
    this.pauseFor,
    this.listenFor,
    this.logEvents,
    this.debugLogging,
  );

  SpeechExampleConfig copyWith({
    SpeechListenOptions? options,
    String? localeId,
    bool? logEvents,
    int? pauseFor,
    int? listenFor,
    bool? debugLogging,
  }) {
    return SpeechExampleConfig(
      options ?? this.options,
      localeId ?? this.localeId,
      pauseFor ?? this.pauseFor,
      listenFor ?? this.listenFor,
      logEvents ?? this.logEvents,
      debugLogging ?? this.debugLogging,
    );
  }
}

/// Show the setup dialog to allow the user to change the
/// configuration of the speech recognition session.
Future<SpeechExampleConfig> showSetUp(
  BuildContext context,
  SpeechExampleConfig currentOptions,
  List<LocaleName> localeNames,
) async {
  var updatedOptions = currentOptions;
  var listenController = TextEditingController()
    ..text = updatedOptions.listenFor.toString();
  var pauseController = TextEditingController()
    ..text = updatedOptions.pauseFor.toString();
  var showHelp = false;
  await showModalBottomSheet(
    elevation: 0,
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Material(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).copyWith().size.height * 0.75,
            minHeight: MediaQuery.of(context).copyWith().size.height * 0.5,
            maxWidth: double.infinity,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Session Options",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          16.0,
                          0.0,
                          16.0,
                          16.0,
                        ),
                        child: showHelp
                            ? const HelpWidget()
                            : SessionOptionsWidget(
                                onChange: (newOptions) {
                                  setState(() {
                                    updatedOptions = newOptions;
                                  });
                                },
                                listenForController: listenController,
                                pauseForController: pauseController,
                                options: updatedOptions,
                                localeNames: localeNames,
                              ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0.0,
                  top: 0.0,
                  child: IconButton(
                    onPressed: () => setState(() => showHelp = !showHelp),
                    icon: Icon(showHelp ? Icons.settings : Icons.question_mark),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  updatedOptions = updatedOptions.copyWith(
    listenFor: int.tryParse(listenController.text) ?? updatedOptions.listenFor,
    pauseFor: int.tryParse(pauseController.text) ?? updatedOptions.pauseFor,
  );
  return updatedOptions;
}

class HelpWidget extends StatelessWidget {
  const HelpWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The plugin provides a number of options that can be set to control '
          'the behavior of the speech recognition. The option names shown '
          'correspond to the names of the fields in the SpeechListenOptions, '
          'or parameters of the listen or initialize methods. ',
        ),
        Text(''),
        Text('localeId:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'The language to use for speech recognition. This is '
          'based on the languages installed on the device. ',
        ),
        Text(''),
        Text('pauseFor:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'The number of seconds to pause after the last speech is '
          'detected before stopping the recognition. Note that this is '
          'ignored on Android devices which impose their own quite short '
          'pause duration. ',
        ),
        Text(''),
        Text('listenFor:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'The maximum number of seconds to listen for speech '
          'before stopping the recognition. Note that the actual time '
          'may be less if the device imposes a shorter maximum duration. ',
        ),
        Text(''),
        Text('partialResults:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'When true the plugin will return results as they are recognized. '
          'When false the plugin will only return the final result. Note '
          'that recognizers will change the recognized result as more '
          'speech is received. This means that the final result may be '
          'different from the last partial result. ',
        ),
        Text(''),
        Text('onDevice:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'When true all recognition will be done on device. '
          'Recognition will fail if the device does not support on device '
          'recognition for the selected language. ',
        ),
        Text(''),
        Text('cancelOnError:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'When true the plugin will automatically cancel recognition  '
          'when an error occurs. If false it will attempt to continue '
          'recognition until the stop or cancel method is called. ',
        ),
        Text(''),
        Text('debugLogging:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'When true the device specific implementation will log '
          'more detailed information during initialization and recognition. ',
        ),
        Text(''),
        Text('autoPunctuation:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'When true the plugin will attempt to add punctuation to the '
          'recognized text on supported devices. ',
        ),
        Text(''),
        Text(
          'enableHapticFeedback:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'When true the plugin will provide haptic feedback during '
          'recognition. Some platforms disable haptics during recognition '
          'to improve accuracy. This option allows the user to override '
          'that behavior. ',
        ),
        Text(''),
        Text('logEvents:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'Logs example app events to the console. '
          'This is not a plugin feature, purely a part of the example app. ',
        ),
      ],
    );
  }
}

/// A simple widget that displays a microphone icon
/// and a circle that changes size based on the sound level.
class MicrophoneWidget extends StatelessWidget {
  const MicrophoneWidget({super.key, required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            blurRadius: .26,
            spreadRadius: level * 1.5,
            color: Colors.black.withValues(alpha: .05),
          ),
        ],
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(50)),
      ),
      child: IconButton(icon: const Icon(Icons.mic), onPressed: () {}),
    );
  }
}

//------------------------------------SECTION 2----------------------
//-------------------LEVINSTEIN DISTANCE CODE -----------------------
//--Application CHECKING code-
//LEVINSTEIN DISTANCE CODE from claude.ai
/// Calculates the Levenshtein distance between two strings.
/// The Levenshtein distance is the minimum number of single-character edits
/// (insertions, deletions, or substitutions) required to change one string
/// into another.
/// Parameters:
///   [string1] - The first string to compare
///   [string2] - The second string to compare
/// Returns:
///   An integer representing the Levenshtein distance between the two strings
int levenshteinDistance(String string1, String string2) {
  // Handle edge cases
  if (string1 == string2) return 0;
  if (string1.isEmpty) return string2.length;
  if (string2.isEmpty) return string1.length;
  final len1 = string1.length;
  final len2 = string2.length;
  // Create a 2D matrix to store distances
  // We use len1 + 1 rows and len2 + 1 columns
  List<List<int>> matrix = List.generate(
    len1 + 1,
    (i) => List.filled(len2 + 1, 0),
  );
  // Initialize first column (deletions from string1)
  for (int i = 0; i <= len1; i++) {
    matrix[i][0] = i;
  }
  // Initialize first row (insertions to match string2)
  for (int j = 0; j <= len2; j++) {
    matrix[0][j] = j;
  }
  // Fill in the rest of the matrix
  for (int i = 1; i <= len1; i++) {
    for (int j = 1; j <= len2; j++) {
      // Cost of substitution (0 if characters match, 1 if they don't)
      int cost = string1[i - 1] == string2[j - 1] ? 0 : 1;
      matrix[i][j] = [
        matrix[i - 1][j] + 1, // Deletion
        matrix[i][j - 1] + 1, // Insertion
        matrix[i - 1][j - 1] + cost, // Substitution
      ].reduce((a, b) => a < b ? a : b);
    }
  }
  // The bottom-right cell contains the final distance
  return matrix[len1][len2];
}

// Example usage and test cases

// Test cases
// print('Levenshtein Distance Examples:');
// print('--------------------------------');
// Example 1: Identical strings
//  print('kitten vs kitten: ${levenshteinDistance('kitten', 'kitten')}'); // 0
// Example 2: Classic example
//  print('kitten vs sitting: ${levenshteinDistance('kitten', 'sitting')}'); // 3
// Example 3: One empty string
// print('hello vs "": ${levenshteinDistance('hello', '')}'); // 5
// Example 4: Completely different strings
// print('abc vs xyz: ${levenshteinDistance('abc', 'xyz')}'); // 3
// Example 5: One character difference
// print('book vs cook: ${levenshteinDistance('book', 'cook')}'); // 1
// Example 6: Case sensitive
// print(
//    'Flutter vs flutter: ${levenshteinDistance('Flutter', 'flutter')}',
// ); // 1
//------------------------------------SECTION 3----------------------
//--Application CHECKING code-

///APPLICATION CHECKING CODE from claude.ai
/////Taken from pub.dev:
//This is Code section for Checking Which Applications are installed
//Dependent on the following packages
//import 'package:installed_apps/installed_apps.dart';
//import 'package:device_apps/device_apps.dart';
//
//

// Data class to hold app installation information
class AppInstallInfo {
  final String packageName;
  final bool isInstalled;
  final String? version;
  final String? appName;
  final String? playStoreUrl;

  AppInstallInfo({
    required this.packageName,
    required this.isInstalled,
    this.version,
    this.appName,
    this.playStoreUrl,
  });
}

// Main class for checking app installations
class AppChecker {
  // List of popular apps to check with their package names
  static final Map<String, String> popularApps = {
    // Social Media
    'WhatsApp': 'com.whatsapp',
    'Facebook': 'com.facebook.katana',
    'Instagram': 'com.instagram.android',
    'Twitter (X)': 'com.twitter.android',
    'Snapchat': 'com.snapchat.android',
    'TikTok': 'com.zhiliaoapp.musically',
    'LinkedIn': 'com.linkedin.android',
    'Telegram': 'org.telegram.messenger',
    'Discord': 'com.discord',

    // Video Calling
    'Zoom': 'us.zoom.videomeetings',
    'Microsoft Teams': 'com.microsoft.teams',
    'Google Meet': 'com.google.android.apps.tachyon',
    'Skype': 'com.skype.raider',
    'FaceTime': 'com.apple.facetime', // iOS only, won't be found on Android
    // Entertainment
    'YouTube': 'com.google.android.youtube',
    'Netflix': 'com.netflix.mediaclient',
    'Spotify': 'com.spotify.music',
    'Amazon Prime Video': 'com.amazon.avod.thirdpartyclient',
    'Disney+': 'com.disney.disneyplus',
    'Twitch': 'tv.twitch.android.app',

    // Productivity
    'Gmail': 'com.google.android.gm',
    'Google Drive': 'com.google.android.apps.docs',
    'Microsoft Office': 'com.microsoft.office.officehubrow',
    'Dropbox': 'com.dropbox.android',
    'Evernote': 'com.evernote',
    'Notion': 'notion.id',

    // Navigation & Travel
    'Google Maps': 'com.google.android.apps.maps',
    'Uber': 'com.ubercab',
    'Lyft': 'me.lyft.android',
    'Waze': 'com.waze',

    // Banking & Finance
    'PayPal': 'com.paypal.android.p2pmobile',
    'Venmo': 'com.venmo',
    'Cash App': 'com.squareup.cash',
    'Robinhood': 'com.robinhood.android',

    // Shopping
    'Amazon Shopping': 'com.amazon.mShop.android.shopping',
    'eBay': 'com.ebay.mobile',
    'AliExpress': 'com.alibaba.aliexpresshd',

    // Games
    'Candy Crush Saga': 'com.king.candycrushsaga',
    'Among Us': 'com.innersloth.spacemafia',
    'PUBG Mobile': 'com.tencent.ig',
    'Minecraft': 'com.mojang.minecraftpe',

    // Utilities
    'Chrome': 'com.android.chrome',
    'Firefox': 'org.mozilla.firefox',
    'VLC': 'org.videolan.vlc',
    'Adobe Acrobat Reader': 'com.adobe.reader',
  };

  // Check if a single app is installed
  static Future<AppInstallInfo> checkSingleApp(
    String appName,
    String packageName,
  ) async {
    try {
      bool isInstalled = await DeviceApps.isAppInstalled(packageName);

      if (isInstalled) {
        Application? app = await DeviceApps.getApp(packageName, true);
        return AppInstallInfo(
          packageName: packageName,
          isInstalled: true,
          version: (app is ApplicationWithIcon) ? app.versionName : null,
          appName: app?.appName,
          playStoreUrl:
              'https://play.google.com/store/apps/details?id=$packageName',
        );
      } else {
        return AppInstallInfo(
          packageName: packageName,
          isInstalled: false,
          playStoreUrl:
              'https://play.google.com/store/apps/details?id=$packageName',
        );
      }
    } catch (e) {
      print('Error checking $appName: $e');
      return AppInstallInfo(
        packageName: packageName,
        isInstalled: false,
        playStoreUrl:
            'https://play.google.com/store/apps/details?id=$packageName',
      );
    }
  }

  // Check all popular apps
  static Future<Map<String, AppInstallInfo>> checkPopularApps() async {
    Map<String, AppInstallInfo> results = {};

    for (String appName in popularApps.keys) {
      String packageName = popularApps[appName]!;
      AppInstallInfo info = await checkSingleApp(appName, packageName);
      results[appName] = info;
    }

    return results;
  }

  // Check specific list of apps
  static Future<Map<String, AppInstallInfo>> checkCustomApps(
    Map<String, String> appsToCheck,
  ) async {
    Map<String, AppInstallInfo> results = {};

    for (String appName in appsToCheck.keys) {
      String packageName = appsToCheck[appName]!;
      AppInstallInfo info = await checkSingleApp(appName, packageName);
      results[appName] = info;
    }

    return results;
  }

  // Get only installed apps from the popular list
  static Future<List<String>> getInstalledPopularApps() async {
    Map<String, AppInstallInfo> results = await checkPopularApps();
    return results.entries
        .where((entry) => entry.value.isInstalled)
        .map((entry) => entry.key)
        .toList();
  }

  // Get only not installed apps from the popular list
  static Future<List<String>> getNotInstalledPopularApps() async {
    Map<String, AppInstallInfo> results = await checkPopularApps();
    return results.entries
        .where((entry) => !entry.value.isInstalled)
        .map((entry) => entry.key)
        .toList();
  }

  // Check if specific messaging apps are installed (for voice commands)
  static Future<Map<String, bool>> checkMessagingApps() async {
    Map<String, String> messagingApps = {
      'WhatsApp': 'com.whatsapp',
      'Telegram': 'org.telegram.messenger',
      'Signal': 'org.thoughtcrime.securesms',
      'Facebook Messenger': 'com.facebook.orca',
      'SMS': 'com.android.mms', // Default SMS app
    };

    Map<String, bool> results = {};
    for (String appName in messagingApps.keys) {
      String packageName = messagingApps[appName]!;
      bool isInstalled = await DeviceApps.isAppInstalled(packageName);
      results[appName] = isInstalled;
    }

    return results;
  }

  // Check if video calling apps are installed
  static Future<Map<String, bool>> checkVideoCallingApps() async {
    Map<String, String> videoApps = {
      'Zoom': 'us.zoom.videomeetings',
      'Microsoft Teams': 'com.microsoft.teams',
      'Google Meet': 'com.google.android.apps.tachyon',
      'Skype': 'com.skype.raider',
      'WhatsApp': 'com.whatsapp',
      'Telegram': 'org.telegram.messenger',
    };

    Map<String, bool> results = {};
    for (String appName in videoApps.keys) {
      String packageName = videoApps[appName]!;
      bool isInstalled = await DeviceApps.isAppInstalled(packageName);
      results[appName] = isInstalled;
    }

    return results;
  }
}

// Simple usage example function
Future<void> simpleAppCheck() async {
  // Check if WhatsApp is installed
  AppInstallInfo whatsappInfo = await AppChecker.checkSingleApp(
    'WhatsApp',
    'com.whatsapp',
  );
  print('WhatsApp installed: ${whatsappInfo.isInstalled}');

  // Get all installed popular apps
  List<String> installedApps = await AppChecker.getInstalledPopularApps();
  print('Installed popular apps: $installedApps');

  // Check messaging apps specifically
  Map<String, bool> messagingApps = await AppChecker.checkMessagingApps();
  print('Messaging apps: $messagingApps');

  // Check video calling apps
  Map<String, bool> videoApps = await AppChecker.checkVideoCallingApps();
  print('Video calling apps: $videoApps');
}
