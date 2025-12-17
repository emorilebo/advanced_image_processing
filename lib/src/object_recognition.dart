import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

final _logger = Logger('ObjectRecognition');

/// Represents a detected object in an image
class DetectedObject {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final Map<String, dynamic>? additionalData;

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.additionalData,
  });

  factory DetectedObject.fromMap(Map<dynamic, dynamic> map) {
    return DetectedObject(
      label: map['label'] as String,
      confidence: map['confidence'] as double,
      boundingBox: Rect.fromLTWH(
        map['left'] as double,
        map['top'] as double,
        map['width'] as double,
        map['height'] as double,
      ),
      additionalData: map['additionalData'] as Map<String, dynamic>?,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'confidence': confidence,
      'left': boundingBox.left,
      'top': boundingBox.top,
      'width': boundingBox.width,
      'height': boundingBox.height,
      if (additionalData != null) 'additionalData': additionalData,
    };
  }
}

/// Provides object detection and recognition capabilities
///
/// Current features:
/// - Real-time object detection
/// - Multiple object recognition
/// - Confidence scoring
/// - Bounding box calculation
///
/// Upcoming features in future releases:
/// - Custom ML model support
/// - Specialized detection models for specific industries
/// - Face detection and analysis
/// - Text recognition (OCR)
/// - Pose estimation
class ObjectRecognition {
  static const MethodChannel _channel = 
      MethodChannel('advanced_image_processing_toolkit/object_recognition');
      
  static final _objectDetector = GoogleMlKit.vision.objectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );
  
  static final _textRecognizer = TextRecognizer();
  static final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );
  
  static final _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  /// Detects objects in the given image
  static Future<List<DetectedObject>> detectObjects(
    Uint8List imageBytes,
  ) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(0, 0), // Will be determined by the image
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: 0, // Will be determined by the image
        ),
      );
      
      final objects = await _objectDetector.processImage(inputImage);
      final faces = await _faceDetector.processImage(inputImage);
      final poses = await _poseDetector.processImage(inputImage);
      final text = await _textRecognizer.processImage(inputImage);
      
      final List<DetectedObject> detections = [];
      
      // Process general objects
      for (final object in objects) {
        detections.add(DetectedObject(
          label: object.labels.first.text,
          confidence: object.labels.first.confidence,
          boundingBox: object.boundingBox,
          additionalData: {
            'trackingId': object.trackingId,
            'labels': object.labels.map((l) => {
              'text': l.text,
              'confidence': l.confidence,
            }).toList(),
          },
        ));
      }
      
      // Process faces
      for (final face in faces) {
        detections.add(DetectedObject(
          label: 'Face',
          confidence: face.headEulerAngleY != null ? 1.0 : 0.8,
          boundingBox: face.boundingBox,
          additionalData: {
            'smilingProbability': face.smilingProbability,
            'leftEyeOpenProbability': face.leftEyeOpenProbability,
            'rightEyeOpenProbability': face.rightEyeOpenProbability,
            'headEulerAngleY': face.headEulerAngleY,
            'headEulerAngleZ': face.headEulerAngleZ,
            'hasLandmarks': face.landmarks.isNotEmpty,
            'landmarkCount': face.landmarks.length,
          },
        ));
      }
      
      // Process poses
      for (final pose in poses) {
        // Create a bounding box based on pose landmarks
        Rect poseBoundingBox = _calculatePoseBoundingBox(pose);
        
        detections.add(DetectedObject(
          label: 'Person',
          confidence: 0.9,
          boundingBox: poseBoundingBox,
          additionalData: {
            'landmarks': pose.landmarks.entries.map((entry) => {
              'type': entry.key.toString(),
              'position': {
                'x': entry.value.x,
                'y': entry.value.y
              },
              'inFrameLikelihood': entry.value.likelihood,
            }).toList(),
          },
        ));
      }
      
      // Process text
      for (final block in text.blocks) {
        detections.add(DetectedObject(
          label: 'Text',
          confidence: 0.9,
          boundingBox: block.boundingBox,
          additionalData: {
            'text': block.text,
            'lines': block.lines.map((l) => l.text).toList(),
          },
        ));
      }
      
      _logger.info('Detected ${detections.length} objects using ML Kit');
      return detections;
    } catch (e) {
      _logger.warning('Failed to detect objects using ML Kit: $e');
      return [];
    }
  }
  
  /// Draws bounding boxes around detected objects on the image
  static Future<Uint8List> drawDetections(
    Uint8List imageBytes,
    List<DetectedObject> detections,
  ) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'drawDetections',
        {
          'imageBytes': imageBytes,
          'detections': detections.map((d) => d.toMap()).toList(),
        },
      );
      
      if (result != null) {
        _logger.info('Detections drawn successfully using native implementation');
        return result;
      }
      
      // For now, just return the original image
      // In a future update, we'll implement drawing in Dart
      return imageBytes;
    } catch (e) {
      _logger.warning('Failed to draw detections: $e');
      return imageBytes;
    }
  }
  
  /// Disposes of ML Kit resources
  static Future<void> dispose() async {
    await _objectDetector.close();
    await _textRecognizer.close();
    await _faceDetector.close();
    await _poseDetector.close();
  }

  /// Calculates a bounding box from pose landmarks
  static Rect _calculatePoseBoundingBox(Pose pose) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    
    // Check if there are any landmarks
    if (pose.landmarks.isEmpty) {
      return const Rect.fromLTWH(0, 0, 100, 200); // Default if no landmarks
    }
    
    // Find min and max coordinates
    for (final landmark in pose.landmarks.values) {
      if (landmark.x < minX) minX = landmark.x;
      if (landmark.y < minY) minY = landmark.y;
      if (landmark.x > maxX) maxX = landmark.x;
      if (landmark.y > maxY) maxY = landmark.y;
    }
    
    // Calculate width and height
    double width = maxX - minX;
    double height = maxY - minY;
    
    // Ensure minimum size
    width = width < 50 ? 50 : width;
    height = height < 100 ? 100 : height;
    
    return Rect.fromLTWH(minX, minY, width, height);
  }
} 