import 'dart:convert';



import 'dart:typed_data';



import 'package:audioplayers/audioplayers.dart';



import 'package:flutter/material.dart';



import 'package:http/http.dart' as http;



import 'package:record/record.dart';





void main() {



  runApp(const SpeechSampleApp());



}



class SpeechSampleApp extends StatelessWidget {



  const SpeechSampleApp({super.key});



  @override



  Widget build(BuildContext context) {



    return MaterialApp(



      debugShowCheckedModeBanner: false,



      title: 'Pronunciation Guidance',



      theme: ThemeData(



        useMaterial3: true,



        colorScheme: ColorScheme.fromSeed(



          seedColor: const Color(0xFF7A5A3A),



        ),



        scaffoldBackgroundColor: const Color(0xFFF7F3EC),



      ),



      home: const PronunciationHomePage(),



    );



  }



}



class PronunciationHomePage extends StatefulWidget {



  const PronunciationHomePage({super.key});



  @override



  State<PronunciationHomePage> createState() =>



      _PronunciationHomePageState();



}



class _PronunciationHomePageState extends State<PronunciationHomePage> {



  static const String backendBaseUrl = 'http://127.0.0.1:8081';



  final AudioPlayer teacherAudioPlayer = AudioPlayer();



  final AudioPlayer learnerAudioPlayer = AudioPlayer();



  AudioRecorder? learnerRecorder;



  Uint8List? learnerRecordingBytes;

  String? learnerPlaybackUrl;



  final TextEditingController demoWordController = TextEditingController();



  final TextEditingController demoTeacherController =



      TextEditingController(text: 'Common');



  List<Map<String, dynamic>> demoWords = [];



  bool wordsLoading = true;



  String wordsLoadError = '';



  int selectedWordIndex = 0;



  String targetWord = '';



  String targetEnglish = '';



  String selectedTeacher = '';



  bool selectedHasRecording = false;



  String selectedTeacherUrl = '';



  bool isLearnerRecording = false;

  bool isStartingLearnerRecording = false;



  String? learnerRecordingPath;



  bool isAnalysing = false;



  String statusMessage = '';



  String teacherSttEnglish = '';



  String learnerSttEnglish = '';



  double? englishSttSimilarity;



  String teacherSttSpanish = '';



  String learnerSttSpanish = '';



  double? spanishSttSimilarity;



  double? teacherDuration;



  double? learnerDuration;



  double? learnerOriginalDuration;



  double? learnerCleanDuration;



  double? stressSimilarity;



  double? timingSimilarity;



  double? teacherStressPeak;



  double? learnerStressPeak;



  List<double> teacherStressCurve = [];



  List<double> learnerStressCurve = [];



  List<double> localPitchErrorCurve = [];



  List<String> stressFeedback = [];



  String pitchConfidence = '';



  String accessibilitySummary = '';



  @override

  void initState() {

    super.initState();

    loadLanguageGatheringWords();

  }



  @override

  void dispose() {

    demoWordController.dispose();

    demoTeacherController.dispose();

    teacherAudioPlayer.dispose();

    learnerAudioPlayer.dispose();

    learnerRecorder?.dispose();

    super.dispose();

  }



  Future<void> loadLanguageGatheringWords() async {



    setState(() {



      wordsLoading = true;



      wordsLoadError = '';



    });



    try {



      final response = await http.get(



        Uri.parse('$backendBaseUrl/words'),



      );



      if (response.statusCode != 200) {



        if (!mounted) return;



        setState(() {



          wordsLoading = false;



          wordsLoadError =



              'Could not load words: ${response.statusCode}';



        });



        return;



      }



      final data = jsonDecode(response.body);



      final rawWords =



          (data['words'] as List<dynamic>?) ?? [];



      final loadedWords = rawWords.map((item) {



        final word =



            Map<String, dynamic>.from(item as Map);



        return <String, dynamic>{



          'dharug': (word['dharug'] ?? '').toString(),



          'english': (word['english'] ?? '').toString(),



          'teacher': (word['teacher'] ?? '').toString(),



          'audio_url': word['audio_url'],



          'has_recording': word['has_recording'] == true,



          'utterance_type':



              (word['utterance_type'] ?? '').toString(),



        };



      }).where((word) {



        return word['dharug']



            .toString()



            .trim()



            .isNotEmpty;



      }).toList();



      if (!mounted) return;



      setState(() {



        demoWords = loadedWords;



        wordsLoading = false;



        wordsLoadError = '';



      });



      if (demoWords.isNotEmpty) {



        final firstRecordedIndex =



            demoWords.indexWhere(



          (word) => word['has_recording'] == true,



        );



        selectDemoWord(



          firstRecordedIndex >= 0



              ? firstRecordedIndex



              : 0,



        );



      }



    } catch (e) {



      if (!mounted) return;



      setState(() {



        wordsLoading = false;



        wordsLoadError =



            'Could not load Language-Gathering words: $e';



      });



    }



  }



  void selectDemoWord(int index) {



    final selected = demoWords[index];



    final word =



        (selected['dharug'] ?? '').toString();



    final english =



        (selected['english'] ?? '').toString();



    final teacher =



        (selected['teacher'] ?? '').toString();



    final hasRecording =



        selected['has_recording'] == true;



    final audioUrl =



        (selected['audio_url'] ?? '').toString();



    setState(() {



      selectedWordIndex = index;



      targetWord = word;



      targetEnglish = english;



      selectedTeacher = teacher;



      selectedHasRecording = hasRecording;



      selectedTeacherUrl =



          hasRecording ? audioUrl : '';



      learnerRecordingPath = null;



      learnerRecordingBytes = null;



      isLearnerRecording = false;



      clearAnalysisResults();



      statusMessage = hasRecording



          ? 'Teacher recording available.'



          : 'Teacher recording coming soon.';



    });



  }



  void clearAnalysisResults() {



    teacherSttEnglish = '';



    learnerSttEnglish = '';



    englishSttSimilarity = null;



    teacherSttSpanish = '';



    learnerSttSpanish = '';



    spanishSttSimilarity = null;



    teacherDuration = null;



    learnerDuration = null;



    learnerOriginalDuration = null;



    learnerCleanDuration = null;



    stressSimilarity = null;



    timingSimilarity = null;



    teacherStressPeak = null;



    learnerStressPeak = null;



    teacherStressCurve = [];



    learnerStressCurve = [];



    localPitchErrorCurve = [];



    stressFeedback = [];



    pitchConfidence = '';



    accessibilitySummary = '';



  }



  void addDemoWord() {



    final word =



        demoWordController.text.trim();



    final teacher =



        demoTeacherController.text.trim();



    if (word.isEmpty || teacher.isEmpty) {



      setState(() {



        statusMessage =



            'Enter both the word or sentence and teacher.';



      });



      return;



    }



    setState(() {



      demoWords.add({



        'dharug': word,



        'english': '',



        'teacher': teacher,



        'audio_url': null,



        'has_recording': false,



        'utterance_type':



            word.contains(' ') ? 'sentence' : 'word',



      });



    });



    selectDemoWord(



      demoWords.length - 1,



    );



    demoWordController.clear();



    demoTeacherController.text = 'Common';



  }



  void requestSelectedRecording() {



    setState(() {



      statusMessage =



          'Recording request noted for $targetWord.';



    });



  }



  Future<void> playTeacherAudio() async {



    if (!selectedHasRecording ||



        selectedTeacherUrl.isEmpty) {



      setState(() {



        statusMessage =



            'Teacher recording coming soon.';



      });



      return;



    }



    try {



      await teacherAudioPlayer.stop();



      await teacherAudioPlayer.play(



        UrlSource(selectedTeacherUrl),



      );



    } catch (e) {



      if (!mounted) return;



      setState(() {



        statusMessage =



            'Could not play teacher audio: $e';



      });



    }



  }



  Future<void> startLearnerAttempt() async {
    if (isLearnerRecording || isStartingLearnerRecording) {
      return;
    }

    if (!selectedHasRecording) {
      setState(() {
        statusMessage =
            'A teacher reference recording is required first.';
      });
      return;
    }

    setState(() {
      isStartingLearnerRecording = true;
      statusMessage = 'Starting microphone...';
    });

    try {
      // Use a brand-new recorder for every attempt.
      try {
        await learnerRecorder?.dispose();
      } catch (_) {}

      learnerRecorder = AudioRecorder();

      final hasPermission =
          await learnerRecorder!.hasPermission();

      if (!hasPermission) {
        if (!mounted) {
          return;
        }

        setState(() {
          isStartingLearnerRecording = false;
          statusMessage =
              'Microphone permission was not granted.';
        });
        return;
      }

      await learnerAudioPlayer.stop();

      // Do not allow an older attempt to remain active while
      // a new recording is being captured.
      learnerRecordingPath = null;
      learnerRecordingBytes = null;
      learnerPlaybackUrl = null;

      clearAnalysisResults();

      // Give Chrome a brief moment to release the previous
      // MediaRecorder / microphone session.
      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      await learnerRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
        path: '',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isStartingLearnerRecording = false;
        isLearnerRecording = true;
        statusMessage =
            'Recording... Speak clearly, then press Stop.';
      });

      debugPrint('FRESH LEARNER RECORDER STARTED');
    } catch (e) {
      debugPrint('START RECORDING ERROR: $e');

      try {
        await learnerRecorder?.dispose();
      } catch (_) {}

      learnerRecorder = null;

      if (!mounted) {
        return;
      }

      setState(() {
        isStartingLearnerRecording = false;
        isLearnerRecording = false;
        statusMessage =
            'Could not start recording: $e';
      });
    }
  }

  Future<void> stopLearnerAttempt() async {
    final recorder = learnerRecorder;

    if (recorder == null) {
      return;
    }

    try {
      final path = await recorder.stop();

      if (path == null || path.isEmpty) {
        throw Exception(
          'No recording was captured.',
        );
      }

      // Read the browser Blob immediately, before disposing
      // the recorder that created it.
      final response = await http.get(
        Uri.parse(path),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Could not read recorded audio.',
        );
      }

      final bytes = response.bodyBytes;

      if (bytes.length < 1000) {
        throw Exception(
          'Recording was empty.',
        );
      }

      // Keep an independent copy of the exact WAV bytes.
      final stableBytes =
          Uint8List.fromList(bytes);

      // The WAV bytes are now safe, so release this recorder.
      await recorder.dispose();
      learnerRecorder = null;

      // Upload a playback copy to Flask. This avoids relying
      // on the temporary Chrome blob URL for later playback.
      final playbackRequest =
          http.MultipartRequest(
        'POST',
        Uri.parse(
          '$backendBaseUrl/learner-audio-upload',
        ),
      );

      playbackRequest.files.add(
        http.MultipartFile.fromBytes(
          'learner_audio',
          stableBytes,
          filename: 'learner_playback.wav',
        ),
      );

      final playbackStreamed =
          await playbackRequest.send();

      final playbackResponse =
          await http.Response.fromStream(
        playbackStreamed,
      );

      if (playbackResponse.statusCode != 200) {
        throw Exception(
          'Could not prepare learner playback: '
          '${playbackResponse.statusCode} '
          '${playbackResponse.body}',
        );
      }

      final playbackData =
          Map<String, dynamic>.from(
        jsonDecode(
          playbackResponse.body,
        ) as Map,
      );

      final playbackUrl =
          (playbackData['audio_url'] ?? '')
              .toString()
              .trim();

      if (playbackUrl.isEmpty) {
        throw Exception(
          'Backend returned no learner audio URL.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        isStartingLearnerRecording = false;
        isLearnerRecording = false;
        learnerRecordingPath = path;
        learnerRecordingBytes = stableBytes;
        learnerPlaybackUrl = playbackUrl;
        statusMessage =
            'Learner recording ready ✓';
      });
    } catch (e) {
      try {
        await learnerRecorder?.dispose();
      } catch (_) {}

      learnerRecorder = null;

      if (!mounted) {
        return;
      }

      setState(() {
        isStartingLearnerRecording = false;
        isLearnerRecording = false;
        learnerRecordingPath = null;
        learnerRecordingBytes = null;
        learnerPlaybackUrl = null;
        statusMessage =
            'Recording error: $e';
      });
    }
  }

  Future<void> playLearnerAudio() async {
    final playbackUrl =
        learnerPlaybackUrl;

    if (playbackUrl == null ||
        playbackUrl.isEmpty) {
      setState(() {
        statusMessage =
            'No learner recording is available yet.';
      });

      return;
    }

    try {
      await learnerAudioPlayer.stop();

      // Force the web player to treat every take as a fresh URL.
      final freshUrl =
          '$playbackUrl'
          '?t=${DateTime.now().millisecondsSinceEpoch}';

      await learnerAudioPlayer.play(
        UrlSource(
          freshUrl,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        statusMessage =
            'Playing learner recording.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        statusMessage =
            'Could not play learner recording: $e';
      });
    }
  }

  Future<void> runPronunciationAnalysis() async {



    if (!selectedHasRecording ||



        selectedTeacherUrl.isEmpty) {



      setState(() {



        statusMessage =



            'Teacher recording coming soon.';



      });



      return;



    }



    final recordedBytes =



        learnerRecordingBytes;



    if (recordedBytes == null ||



        recordedBytes.isEmpty) {



      setState(() {



        statusMessage =



            'Please record a learner attempt first.';



      });



      return;



    }



    setState(() {



      isAnalysing = true;



      clearAnalysisResults();



      statusMessage =



          'Analysing pronunciation guidance...';



    });



    try {



      final request =



          http.MultipartRequest(



        'POST',



        Uri.parse(



          '$backendBaseUrl/compare-upload',



        ),



      );



      request.fields['teacher_url'] =



          selectedTeacherUrl;



      request.fields['target_word'] =



          targetWord;



      request.files.add(



        http.MultipartFile.fromBytes(



          'learner_audio',



          recordedBytes,



          filename:



              'learner_attempt.wav',



        ),



      );



      final streamedResponse =



          await request.send();



      final response =



          await http.Response.fromStream(



        streamedResponse,



      );



      if (response.statusCode != 200) {



        if (!mounted) return;



        setState(() {



          isAnalysing = false;



          statusMessage =



              'Analysis failed: '



              '${response.statusCode} '



              '${response.body}';



        });



        return;



      }



      final data =



          Map<String, dynamic>.from(



        jsonDecode(response.body) as Map,



      );



      final teacherStress =



          _mapFrom(



        data['teacher_stress'],



      );



      final learnerStress =



          _mapFrom(



        data['learner_stress'],



      );



      final trimInfo =



          _mapFrom(



        data['learner_trim_info'],



      );



      final stressComparison =



          _mapFrom(



        data['stress_comparison'],



      );



      if (!mounted) return;



      setState(() {



        teacherSttEnglish =



            (data['teacher_stt'] ?? '')



                .toString()



                .trim();



        learnerSttEnglish =



            (data['learner_stt'] ??



                    data['stt_text'] ??



                    '')



                .toString()



                .trim();



        englishSttSimilarity =



            _doubleFrom(



          data['stt_similarity'],



        );



        teacherSttSpanish =



            (data['teacher_stt_spanish'] ?? '')



                .toString()



                .trim();



        learnerSttSpanish =



            (data['learner_stt_spanish'] ?? '')



                .toString()



                .trim();



        spanishSttSimilarity =



            _doubleFrom(



          data['stt_similarity_spanish'],



        );



        teacherDuration =



            _doubleFrom(



          teacherStress['duration'],



        );



        learnerDuration =



            _doubleFrom(



          learnerStress['duration'],



        );



        learnerOriginalDuration =



            _doubleFrom(



          trimInfo['original_duration'],



        );



        learnerCleanDuration =



            _doubleFrom(



          trimInfo['trimmed_duration'],



        );



        stressSimilarity =



            _doubleFrom(



          stressComparison['stress_similarity'] ??



              data['pitch_similarity'],



        );



        timingSimilarity =



            _doubleFrom(



          data['timing_similarity'] ??



              stressComparison['timing_similarity'],



        );



        teacherStressPeak =



            _doubleFrom(



          stressComparison[



                  'teacher_pitch_peak_percent'] ??



              stressComparison[



                  'teacher_peak_percent'],



        );



        learnerStressPeak =



            _doubleFrom(



          stressComparison[



                  'learner_pitch_peak_percent'] ??



              stressComparison[



                  'learner_peak_percent'],



        );



        teacherStressCurve =



            _doubleList(



          stressComparison[



                  'teacher_pitch_curve'] ??



              stressComparison['teacher_curve'],



        );



        learnerStressCurve =



            _doubleList(



          stressComparison[



                  'learner_pitch_curve'] ??



              stressComparison['learner_curve'],



        );



        localPitchErrorCurve =



            _doubleList(



          data['local_pitch_error_curve'] ??



              stressComparison[



                  'local_pitch_error_curve'],



        );



        stressFeedback =



            ((stressComparison['pitch_feedback']



                        as List<dynamic>?) ??



                    (stressComparison['feedback']



                        as List<dynamic>?) ??



                    [])



                .map(



                  (value) =>



                      value.toString(),



                )



                .toList();



        pitchConfidence =



            (data['pitch_confidence'] ?? '')



                .toString()



                .trim();



        accessibilitySummary =



            (data['accessibility_summary'] ??



                    stressComparison[



                        'accessibility_summary'] ??



                    '')



                .toString()



                .trim();



        isAnalysing = false;



        statusMessage =



            'Pronunciation guidance ready.';



      });



    } catch (e) {



      if (!mounted) return;



      setState(() {



        isAnalysing = false;



        statusMessage =



            'Analysis error: $e';



      });



    }



  }



  Map<String, dynamic> _mapFrom(



    dynamic value,



  ) {



    if (value is Map) {



      return Map<String, dynamic>.from(



        value,



      );



    }



    return <String, dynamic>{};



  }



  double? _doubleFrom(



    dynamic value,



  ) {



    if (value is num) {



      return value.toDouble();



    }



    return null;



  }



  List<double> _doubleList(



    dynamic value,



  ) {



    if (value is! List) {



      return [];



    }



    return value



        .whereType<num>()



        .map(



          (item) => item.toDouble(),



        )



        .toList();



  }



  Widget _sectionCard({



    required String title,



    required Widget child,



  }) {



    return Padding(



      padding:



          const EdgeInsets.symmetric(



        horizontal: 16,



        vertical: 8,



      ),



      child: Card(



        child: Padding(



          padding:



              const EdgeInsets.all(18),



          child: Column(



            crossAxisAlignment:



                CrossAxisAlignment.stretch,



            children: [



              Text(



                title,



                textAlign:



                    TextAlign.center,



                style:



                    const TextStyle(



                  fontSize: 20,



                  fontWeight:



                      FontWeight.bold,



                ),



              ),



              const SizedBox(height: 14),



              child,



            ],



          ),



        ),



      ),



    );



  }



  Widget _similarityLine(



    String label,



    double? value,



  ) {



    if (value == null) {



      return Text('$label: -');



    }



    return Text(



      '$label: '



      '${(value * 100).toStringAsFixed(1)}%',



      style:



          const TextStyle(



        fontWeight:



            FontWeight.bold,



      ),



    );



  }



  @override



  Widget build(



    BuildContext context,



  ) {



    return Scaffold(



      appBar: AppBar(



        title:



            const Text(



          'Pronunciation Guidance',



        ),



      ),



      body: SingleChildScrollView(



        padding:



            const EdgeInsets.only(



          bottom: 32,



        ),



        child: Column(



          children: [



            _buildWordSelector(),



            if (selectedHasRecording)



              _buildLearnerAttemptSection(),



            if (statusMessage.isNotEmpty)



              Padding(



                padding:



                    const EdgeInsets.symmetric(



                  horizontal: 20,



                  vertical: 8,



                ),



                child: Text(



                  statusMessage,



                  textAlign:



                      TextAlign.center,



                ),



              ),



            if (isAnalysing)



              const Padding(



                padding:



                    EdgeInsets.all(16),



                child:



                    CircularProgressIndicator(),



              ),



            if (teacherSttEnglish.isNotEmpty ||



                learnerSttEnglish.isNotEmpty)



              _buildSpeechRecognitionResults(),



            if (teacherStressCurve.isNotEmpty ||



                learnerStressCurve.isNotEmpty)



              _buildGuidanceResults(),



          ],



        ),



      ),



    );



  }



  Widget _buildWordSelector() {



    final isSentence =



        targetWord.trim().contains(' ');



    return Padding(



      padding:



          const EdgeInsets.all(16),



      child: Card(



        child: Padding(



          padding:



              const EdgeInsets.all(18),



          child: Column(



            crossAxisAlignment:



                CrossAxisAlignment.stretch,



            children: [



              const Text(



                'SELECT WORD OR SENTENCE',



                style:



                    TextStyle(



                  fontSize: 17,



                  fontWeight:



                      FontWeight.bold,



                ),



              ),



              const SizedBox(height: 12),



              if (wordsLoading)



                const Center(



                  child:



                      CircularProgressIndicator(),



                )



              else if (wordsLoadError.isNotEmpty)



                Text(



                  wordsLoadError,



                  style:



                      const TextStyle(



                    color:



                        Colors.red,



                  ),



                )



              else if (demoWords.isEmpty)



                const Text(



                  'No Language-Gathering items found.',



                )



              else



                DropdownButton<int>(



                  value:



                      selectedWordIndex,



                  isExpanded:



                      true,



                  items:



                      List.generate(



                    demoWords.length,



                    (index) {



                      final word =



                          demoWords[index];



                      final recorded =



                          word['has_recording'] ==



                              true;



                      return DropdownMenuItem<int>(



                        value: index,



                        child: Text(



                          '${word['dharug']} — '



                          '${word['english']} — '



                          '${word['teacher']}'



                          '${recorded ? ' ✓' : ' — recording coming soon'}',



                          overflow:



                              TextOverflow.ellipsis,



                        ),



                      );



                    },



                  ),



                  onChanged:



                      (index) {



                    if (index != null) {



                      selectDemoWord(index);



                    }



                  },



                ),



              if (targetWord.isNotEmpty) ...[



                const SizedBox(height: 20),



                Text(



                  targetWord,



                  textAlign:



                      TextAlign.center,



                  style:



                      const TextStyle(



                    fontSize: 30,



                    fontWeight:



                        FontWeight.bold,



                  ),



                ),



                if (targetEnglish.isNotEmpty)



                  Text(



                    targetEnglish,



                    textAlign:



                        TextAlign.center,



                  ),



                if (selectedTeacher.isNotEmpty)



                  Text(



                    'Teacher: $selectedTeacher',



                    textAlign:



                        TextAlign.center,



                  ),



                const SizedBox(height: 6),



                Text(



                  isSentence



                      ? 'Sentence / phrase practice'



                      : 'Word practice',



                  textAlign:



                      TextAlign.center,



                  style:



                      Theme.of(context)



                          .textTheme



                          .labelLarge,



                ),



                const SizedBox(height: 14),



              ],



              if (selectedHasRecording)



                const Row(



                  children: [



                    Icon(



                      Icons.check_circle,



                      color:



                          Colors.green,



                    ),



                    SizedBox(width: 8),



                    Expanded(



                      child: Text(



                        'Teacher recording available',



                        style:



                            TextStyle(



                          fontWeight:



                              FontWeight.bold,



                        ),



                      ),



                    ),



                  ],



                )



              else if (!wordsLoading &&



                  targetWord.isNotEmpty)



                Column(



                  children: [



                    const Text(



                      'Teacher recording coming soon',



                      style:



                          TextStyle(



                        fontSize: 17,



                        fontWeight:



                            FontWeight.bold,



                      ),



                    ),



                    const SizedBox(height: 6),



                    const Text(



                      'A teacher reference recording is required before pronunciation analysis can be performed.',



                      textAlign:



                          TextAlign.center,



                    ),



                    const SizedBox(height: 10),



                    ElevatedButton.icon(



                      onPressed:



                          requestSelectedRecording,



                      icon:



                          const Icon(



                        Icons.record_voice_over,



                      ),



                      label:



                          const Text(



                        'Request Recording',



                      ),



                    ),



                  ],



                ),



              const SizedBox(height: 18),



              const Divider(),



              const SizedBox(height: 10),



              const Text(



                'ADD EXISTING / NEW ITEM',



                style:



                    TextStyle(



                  fontWeight:



                      FontWeight.bold,



                ),



              ),



              const SizedBox(height: 10),



              TextField(



                controller:



                    demoWordController,



                decoration:



                    const InputDecoration(



                  labelText:



                      'Dharug word or sentence',



                  border:



                      OutlineInputBorder(),



                ),



              ),



              const SizedBox(height: 10),



              TextField(



                controller:



                    demoTeacherController,



                decoration:



                    const InputDecoration(



                  labelText:



                      'Teacher',



                  border:



                      OutlineInputBorder(),



                ),



              ),



              const SizedBox(height: 10),



              ElevatedButton.icon(



                onPressed:



                    addDemoWord,



                icon:



                    const Icon(



                  Icons.add,



                ),



                label:



                    const Text(



                  'Add and Load Item',



                ),



              ),



            ],



          ),



        ),



      ),



    );



  }



  Widget _buildLearnerAttemptSection() {



    return _sectionCard(



      title:



          'LEARNER PRONUNCIATION ATTEMPT',



      child: Column(



        children: [



          Wrap(



            alignment:



                WrapAlignment.center,



            spacing: 12,



            runSpacing: 10,



            children: [



              ElevatedButton.icon(



                onPressed:



                    isLearnerRecording



                        ? null



                        : startLearnerAttempt,



                icon:



                    const Icon(



                  Icons.mic,



                ),



                label:



                    const Text(



                  'Start Recording',



                ),



              ),



              ElevatedButton.icon(



                onPressed:



                    isLearnerRecording



                        ? stopLearnerAttempt



                        : null,



                icon:



                    const Icon(



                  Icons.stop,



                ),



                label:



                    const Text(



                  'Stop Recording',



                ),



              ),



            ],



          ),



          const SizedBox(height: 12),



          if (isLearnerRecording)



            const Text(



              'Recording...',



              style:



                  TextStyle(



                fontWeight:



                    FontWeight.bold,



              ),



            ),



          if (!isLearnerRecording &&



              learnerRecordingBytes != null)



            const Text(



              'Learner recording ready ✓',



              style:



                  TextStyle(



                fontWeight:



                    FontWeight.bold,



              ),



            ),



          const SizedBox(height: 12),



          Wrap(



            alignment:



                WrapAlignment.center,



            spacing: 12,



            runSpacing: 10,



            children: [



              ElevatedButton.icon(



                onPressed:



                    playTeacherAudio,



                icon:



                    const Icon(



                  Icons.volume_up,



                ),



                label:



                    const Text(



                  'Listen to Teacher',



                ),



              ),



              ElevatedButton.icon(



                onPressed:



                    learnerRecordingBytes ==



                            null



                        ? null



                        : playLearnerAudio,



                icon:



                    const Icon(



                  Icons.play_arrow,



                ),



                label:



                    const Text(



                  'Listen to My Recording',



                ),



              ),



            ],



          ),



          const SizedBox(height: 14),



          ElevatedButton.icon(



            onPressed:



                learnerRecordingBytes ==



                            null ||



                        isAnalysing



                    ? null



                    : runPronunciationAnalysis,



            icon:



                const Icon(



              Icons.graphic_eq,



            ),



            label:



                Text(



              isAnalysing



                  ? 'Analysing...'



                  : 'Analyse Pronunciation',



            ),



          ),



        ],



      ),



    );



  }



  Widget _buildSpeechRecognitionResults() {



    return _sectionCard(



      title:



          'EXPERIMENTAL SPEECH RECOGNITION',



      child: Column(



        crossAxisAlignment:



            CrossAxisAlignment.stretch,



        children: [



          const Text(



            'These models are experimental phonetic clues only. '



            'They are not the final pronunciation score.',



            textAlign:



                TextAlign.center,



          ),



          const SizedBox(height: 18),



          const Text(



            'ENGLISH MODEL',



            style:



                TextStyle(



              fontSize: 17,



              fontWeight:



                  FontWeight.bold,



            ),



          ),



          const SizedBox(height: 6),



          Text(



            'Teacher: '



            '${teacherSttEnglish.isEmpty ? '-' : teacherSttEnglish}',



          ),



          Text(



            'Learner: '



            '${learnerSttEnglish.isEmpty ? '-' : learnerSttEnglish}',



          ),



          _similarityLine(



            'Similarity',



            englishSttSimilarity,



          ),



          const SizedBox(height: 20),



          const Divider(),



          const SizedBox(height: 12),



          const Text(



            'SPANISH MODEL',



            style:



                TextStyle(



              fontSize: 17,



              fontWeight:



                  FontWeight.bold,



            ),



          ),



          const SizedBox(height: 6),



          Text(



            'Teacher: '



            '${teacherSttSpanish.isEmpty ? '-' : teacherSttSpanish}',



          ),



          Text(



            'Learner: '



            '${learnerSttSpanish.isEmpty ? '-' : learnerSttSpanish}',



          ),



          _similarityLine(



            'Similarity',



            spanishSttSimilarity,



          ),



        ],



      ),



    );



  }



  Widget _buildGuidanceResults() {



    final utteranceLabel =



        targetWord.trim().contains(' ')



            ? 'utterance'



            : 'word';



    return _sectionCard(



      title:



          'PITCH, STRESS & TIMING GUIDANCE',



      child: Column(



        crossAxisAlignment:



            CrossAxisAlignment.stretch,



        children: [



          const Text(



            'Follow the teacher pattern, compare your attempt, then use the matched view to see where they differ.',



            textAlign:



                TextAlign.center,



          ),



          const SizedBox(height: 18),



          if (stressSimilarity != null)



            _resultChip(



              icon:



                  Icons.multiline_chart,



              label:



                  'Pitch / stress pattern',



              value:



                  '${(stressSimilarity! * 100).toStringAsFixed(1)}%',



            ),



          if (timingSimilarity != null) ...[



            const SizedBox(height: 8),



            _resultChip(



              icon:



                  Icons.timer_outlined,



              label:



                  'Timing match',



              value:



                  '${(timingSimilarity! * 100).toStringAsFixed(1)}%',



            ),



          ],



          if (pitchConfidence.isNotEmpty) ...[



            const SizedBox(height: 8),



            _resultChip(



              icon:



                  Icons.verified_outlined,



              label:



                  'Analysis confidence',



              value:



                  pitchConfidence.toUpperCase(),



            ),



          ],



          const SizedBox(height: 24),



          if (teacherStressCurve.isNotEmpty) ...[



            _guidanceGraph(



              title:



                  '1. TEACHER REFERENCE',



              subtitle:



                  'First, look at the teacher pattern and listen again if needed.',



              teacherCurve:



                  teacherStressCurve,



              learnerCurve:



                  const [],



              semanticLabel:



                  'Teacher pitch and stress pattern.',



            ),



            if (teacherStressPeak != null)



              Padding(



                padding:



                    const EdgeInsets.only(



                  top: 8,



                ),



                child: Text(



                  'Teacher main prominence: '



                  '${(teacherStressPeak! * 100).toStringAsFixed(0)}% '



                  'through the $utteranceLabel.',



                  textAlign:



                      TextAlign.center,



                ),



              ),



            const SizedBox(height: 26),



          ],



          if (learnerStressCurve.isNotEmpty) ...[



            _guidanceGraph(



              title:



                  '2. YOUR ATTEMPT',



              subtitle:



                  'Now look at the movement of your own voice.',



              teacherCurve:



                  const [],



              learnerCurve:



                  learnerStressCurve,



              semanticLabel:



                  'Learner pitch and stress pattern.',



            ),



            if (learnerStressPeak != null)



              Padding(



                padding:



                    const EdgeInsets.only(



                  top: 8,



                ),



                child: Text(



                  'Your main prominence: '



                  '${(learnerStressPeak! * 100).toStringAsFixed(0)}% '



                  'through the $utteranceLabel.',



                  textAlign:



                      TextAlign.center,



                ),



              ),



            const SizedBox(height: 26),



          ],



          if (teacherStressCurve.isNotEmpty &&



              learnerStressCurve.isNotEmpty) ...[



            _guidanceGraph(



              title:



                  '3. MATCHED COMPARISON',



              subtitle:



                  'The two patterns are aligned to the same relative timeline. '



                  'Shaded areas show larger differences.',



              teacherCurve:



                  teacherStressCurve,



              learnerCurve:



                  learnerStressCurve,



              errorCurve:



                  localPitchErrorCurve,



              semanticLabel:



                  accessibilitySummary.isNotEmpty



                      ? accessibilitySummary



                      : 'Aligned teacher and learner comparison.',



            ),



            const SizedBox(height: 10),



            const Wrap(



              alignment:



                  WrapAlignment.center,



              spacing: 18,



              runSpacing: 8,



              children: [



                _LegendItem(



                  color:



                      Colors.blue,



                  label:



                      'Teacher',



                  dashed:



                      false,



                ),



                _LegendItem(



                  color:



                      Colors.orange,



                  label:



                      'Your attempt',



                  dashed:



                      true,



                ),



              ],



            ),



            const SizedBox(height: 24),



          ],



          if (accessibilitySummary.isNotEmpty) ...[



            Container(



              padding:



                  const EdgeInsets.all(14),



              decoration:



                  BoxDecoration(



                color:



                    Theme.of(context)



                        .colorScheme



                        .surfaceContainerHighest,



                borderRadius:



                    BorderRadius.circular(14),



              ),



              child:



                  Semantics(



                label:



                    'Graph summary. '



                    '$accessibilitySummary',



                child:



                    Column(



                  crossAxisAlignment:



                      CrossAxisAlignment.start,



                  children: [



                    const Text(



                      'GRAPH SUMMARY',



                      style:



                          TextStyle(



                        fontWeight:



                            FontWeight.bold,



                      ),



                    ),



                    const SizedBox(height: 6),



                    Text(



                      accessibilitySummary,



                    ),



                  ],



                ),



              ),



            ),



            const SizedBox(height: 20),



          ],



          if (stressFeedback.isNotEmpty) ...[



            const Text(



              'WHAT THIS MEANS',



              style:



                  TextStyle(



                fontSize: 17,



                fontWeight:



                    FontWeight.bold,



              ),



            ),



            const SizedBox(height: 8),



            ...stressFeedback.map(



              (feedback) =>



                  Padding(



                padding:



                    const EdgeInsets.only(



                  bottom: 9,



                ),



                child:



                    Row(



                  crossAxisAlignment:



                      CrossAxisAlignment.start,



                  children: [



                    const Padding(



                      padding:



                          EdgeInsets.only(



                        top: 2,



                        right: 8,



                      ),



                      child:



                          Icon(



                        Icons.lightbulb_outline,



                        size: 20,



                      ),



                    ),



                    Expanded(



                      child: Text(



                        feedback,



                      ),



                    ),



                  ],



                ),



              ),



            ),



            const SizedBox(height: 18),



          ],



          if (learnerOriginalDuration != null &&



              learnerCleanDuration != null) ...[



            const Divider(),



            const SizedBox(height: 12),



            const Text(



              'RECORDING ALIGNMENT',



              style:



                  TextStyle(



                fontWeight:



                    FontWeight.bold,



              ),



            ),



            const SizedBox(height: 8),



            Text(



              'Your recording: '



              '${learnerOriginalDuration!.toStringAsFixed(2)} s '



              '→ ${learnerCleanDuration!.toStringAsFixed(2)} s '



              'after removing outer silence.',



            ),



            Text(



              'Teacher speech: '



              '${teacherDuration?.toStringAsFixed(2) ?? '-'} s',



            ),



            Text(



              'Your speech: '



              '${learnerDuration?.toStringAsFixed(2) ?? '-'} s',



            ),



            const SizedBox(height: 18),



          ],



          SizedBox(



            width:



                double.infinity,



            child:



                FilledButton.icon(



              onPressed: () {



                setState(() {



                  learnerRecordingPath = null;



                  learnerRecordingBytes = null;



                  clearAnalysisResults();



                  statusMessage =



                      'Ready for another attempt.';



                });



              },



              icon:



                  const Icon(



                Icons.replay,



              ),



              label:



                  const Text(



                'Try Again',



              ),



            ),



          ),



        ],



      ),



    );



  }



  Widget _resultChip({



    required IconData icon,



    required String label,



    required String value,



  }) {



    return Container(



      padding:



          const EdgeInsets.symmetric(



        horizontal: 14,



        vertical: 12,



      ),



      decoration:



          BoxDecoration(



        border:



            Border.all(



          color:



              Theme.of(context)



                  .colorScheme



                  .outlineVariant,



        ),



        borderRadius:



            BorderRadius.circular(14),



      ),



      child: Row(



        children: [



          Icon(icon),



          const SizedBox(width: 10),



          Expanded(



            child: Text(



              label,



              style:



                  const TextStyle(



                fontWeight:



                    FontWeight.w600,



              ),



            ),



          ),



          Text(



            value,



            style:



                const TextStyle(



              fontWeight:



                  FontWeight.bold,



            ),



          ),



        ],



      ),



    );



  }



  Widget _guidanceGraph({



    required String title,



    required String subtitle,



    required List<double> teacherCurve,



    required List<double> learnerCurve,



    List<double> errorCurve = const [],



    required String semanticLabel,



  }) {



    return Semantics(



      label: semanticLabel,



      image: true,



      child: Column(



        crossAxisAlignment:



            CrossAxisAlignment.stretch,



        children: [



          Text(



            title,



            textAlign:



                TextAlign.center,



            style:



                const TextStyle(



              fontSize: 17,



              fontWeight:



                  FontWeight.bold,



            ),



          ),



          const SizedBox(height: 5),



          Text(



            subtitle,



            textAlign:



                TextAlign.center,



          ),



          const SizedBox(height: 12),



          Container(



            height: 210,



            padding:



                const EdgeInsets.fromLTRB(



              8,



              12,



              8,



              8,



            ),



            decoration:



                BoxDecoration(



              border:



                  Border.all(



                color:



                    Theme.of(context)



                        .colorScheme



                        .outlineVariant,



              ),



              borderRadius:



                  BorderRadius.circular(16),



            ),



            child:



                CustomPaint(



              painter:



                  GuidanceCurvePainter(



                teacherCurve:



                    teacherCurve,



                learnerCurve:



                    learnerCurve,



                errorCurve:



                    errorCurve,



              ),



              child:



                  const SizedBox.expand(),



            ),



          ),



        ],



      ),



    );



  }



}



class GuidanceCurvePainter extends CustomPainter {



  GuidanceCurvePainter({



    required this.teacherCurve,



    required this.learnerCurve,



    this.errorCurve = const [],



  });



  final List<double> teacherCurve;



  final List<double> learnerCurve;



  final List<double> errorCurve;



  @override



  void paint(



    Canvas canvas,



    Size size,



  ) {



    const topPadding = 8.0;



    const bottomPadding = 12.0;



    final graphHeight =



        size.height -



            topPadding -



            bottomPadding;



    final axisPaint =



        Paint()



          ..strokeWidth = 1



          ..color =



              Colors.grey.shade500;



    final teacherPaint =



        Paint()



          ..strokeWidth = 3.5



          ..strokeCap =



              StrokeCap.round



          ..strokeJoin =



              StrokeJoin.round



          ..style =



              PaintingStyle.stroke



          ..color =



              Colors.blue;



    final learnerPaint =



        Paint()



          ..strokeWidth = 3.5



          ..strokeCap =



              StrokeCap.round



          ..strokeJoin =



              StrokeJoin.round



          ..style =



              PaintingStyle.stroke



          ..color =



              Colors.orange;



    final mismatchPaint =



        Paint()



          ..style =



              PaintingStyle.fill



          ..color =



              Colors.orange.withValues(alpha: 0.10);



    canvas.drawLine(



      Offset(



        0,



        size.height -



            bottomPadding,



      ),



      Offset(



        size.width,



        size.height -



            bottomPadding,



      ),



      axisPaint,



    );



    if (errorCurve.length >= 2) {



      for (



        int i = 0;



        i < errorCurve.length - 1;



        i++



      ) {



        final error =



            errorCurve[i]



                .clamp(



                  0.0,



                  1.0,



                )



                .toDouble();



        if (error < 0.20) {



          continue;



        }



        final x1 =



            i /



                (errorCurve.length - 1) *



                size.width;



        final x2 =



            (i + 1) /



                (errorCurve.length - 1) *



                size.width;



        canvas.drawRect(



          Rect.fromLTRB(



            x1,



            topPadding,



            x2,



            size.height -



                bottomPadding,



          ),



          mismatchPaint,



        );



      }



    }



    void drawSolidCurve(



      List<double> curve,



      Paint paint,



    ) {



      if (curve.length < 2) {



        return;



      }



      final path = Path();



      for (



        int i = 0;



        i < curve.length;



        i++



      ) {



        final x =



            i /



                (curve.length - 1) *



                size.width;



        final value =



            curve[i]



                .clamp(



                  0.0,



                  1.0,



                )



                .toDouble();



        final y =



            topPadding +



                (



                  1.0 - value



                ) *



                graphHeight;



        if (i == 0) {



          path.moveTo(



            x,



            y,



          );



        } else {



          path.lineTo(



            x,



            y,



          );



        }



      }



      canvas.drawPath(



        path,



        paint,



      );



    }



    void drawDashedCurve(



      List<double> curve,



      Paint paint,



    ) {



      if (curve.length < 2) {



        return;



      }



      for (



        int i = 0;



        i < curve.length - 1;



        i++



      ) {



        if ((i ~/ 3).isOdd) {



          continue;



        }



        final x1 =



            i /



                (curve.length - 1) *



                size.width;



        final x2 =



            (i + 1) /



                (curve.length - 1) *



                size.width;



        final v1 =



            curve[i]



                .clamp(



                  0.0,



                  1.0,



                )



                .toDouble();



        final v2 =



            curve[i + 1]



                .clamp(



                  0.0,



                  1.0,



                )



                .toDouble();



        final y1 =



            topPadding +



                (



                  1.0 - v1



                ) *



                graphHeight;



        final y2 =



            topPadding +



                (



                  1.0 - v2



                ) *



                graphHeight;



        canvas.drawLine(



          Offset(



            x1,



            y1,



          ),



          Offset(



            x2,



            y2,



          ),



          paint,



        );



      }



    }



    drawSolidCurve(



      teacherCurve,



      teacherPaint,



    );



    drawDashedCurve(



      learnerCurve,



      learnerPaint,



    );



  }



  @override



  bool shouldRepaint(



    covariant GuidanceCurvePainter oldDelegate,



  ) {



    return true;



  }



}



class _LegendItem extends StatelessWidget {



  const _LegendItem({



    required this.color,



    required this.label,



    required this.dashed,



  });



  final Color color;



  final String label;



  final bool dashed;



  @override



  Widget build(



    BuildContext context,



  ) {



    return Row(



      mainAxisSize:



          MainAxisSize.min,



      children: [



        SizedBox(



          width: 28,



          height: 12,



          child:



              CustomPaint(



            painter:



                _LegendLinePainter(



              color: color,



              dashed: dashed,



            ),



          ),



        ),



        const SizedBox(width: 6),



        Text(label),



      ],



    );



  }



}



class _LegendLinePainter extends CustomPainter {



  _LegendLinePainter({



    required this.color,



    required this.dashed,



  });



  final Color color;



  final bool dashed;



  @override



  void paint(



    Canvas canvas,



    Size size,



  ) {



    final paint =



        Paint()



          ..color = color



          ..strokeWidth = 3



          ..strokeCap =



              StrokeCap.round;



    if (!dashed) {



      canvas.drawLine(



        Offset(



          0,



          size.height / 2,



        ),



        Offset(



          size.width,



          size.height / 2,



        ),



        paint,



      );



      return;



    }



    const dash = 5.0;



    const gap = 4.0;



    double x = 0;



    while (x < size.width) {



      canvas.drawLine(



        Offset(



          x,



          size.height / 2,



        ),



        Offset(



          (x + dash)



              .clamp(



                0,



                size.width,



              )



              .toDouble(),



          size.height / 2,



        ),



        paint,



      );



      x += dash + gap;



    }



  }



  @override



  bool shouldRepaint(



    covariant _LegendLinePainter oldDelegate,



  ) {



    return true;



  }



}
