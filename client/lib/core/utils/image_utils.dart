import 'dart:math';

import 'package:data_models/utils/generated_image.dart';

String generateRandomImageUrl({int? seed, int? resolution}) =>
    generatedImageUrl('${seed ?? Random().nextInt(1000)}');
