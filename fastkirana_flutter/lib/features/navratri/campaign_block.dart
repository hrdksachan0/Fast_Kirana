class CampaignMotion {
  final String preset, speed;
  const CampaignMotion({this.preset = 'fade', this.speed = 'normal'});
  factory CampaignMotion.fromJson(Map<String, dynamic> json) {
    if (json.keys.any((key) => !const ['preset', 'speed'].contains(key))) {
      throw const FormatException('Unknown campaign motion option');
    }
    final preset = json.containsKey('preset') ? json['preset'] : 'fade';
    final speed = json.containsKey('speed') ? json['speed'] : 'normal';
    if (!const ['none', 'fade', 'slide', 'float', 'zoom', 'sparkle']
            .contains(preset) ||
        !const ['slow', 'normal', 'fast'].contains(speed)) {
      throw const FormatException('Unsupported campaign motion');
    }
    return CampaignMotion(preset: preset as String, speed: speed as String);
  }
  double get factor => speed == 'slow' ? 1.5 : (speed == 'fast' ? .65 : 1);
  Duration interval(Duration duration) => Duration(
      milliseconds:
          (duration.inMilliseconds * factor).round().clamp(1500, 60000));
  Duration fade(Duration duration) => Duration(
      milliseconds: preset == 'none'
          ? 0
          : (duration.inMilliseconds * factor).round().clamp(0, 1200));
  Duration get loop => Duration(
      milliseconds: speed == 'slow' ? 6000 : (speed == 'fast' ? 2600 : 4000));
}

class CampaignBlock {
  final String id, type, title, body, presentation;
  final bool enabled;
  final String? image, destinationId, tabId;
  final List<String> itemIds;
  final CampaignMotion motion;
  const CampaignBlock(
      {required this.id,
      required this.type,
      this.enabled = true,
      this.title = '',
      this.body = '',
      this.presentation = 'wide',
      this.image,
      this.destinationId,
      this.tabId,
      this.itemIds = const [],
      this.motion = const CampaignMotion()});

  static const presentations = {
    'banner': ['wide'],
    'categories': ['grid', 'row'],
    'spotlight': ['wide', 'offer'],
    'collection': ['grid', 'row'],
    'image': ['wide'],
    'text': ['plain'],
  };

  factory CampaignBlock.fromJson(Map<String, dynamic> json) {
    const fields = [
      'id',
      'type',
      'enabled',
      'title',
      'body',
      'image',
      'destinationId',
      'itemIds',
      'tabId',
      'presentation',
      'motion'
    ];
    if (json.keys.any((key) => !fields.contains(key))) {
      throw const FormatException('Unknown campaign block option');
    }
    String identifier(dynamic value) {
      if (value is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(value.trim())) {
        throw const FormatException('Invalid campaign block reference');
      }
      return value.trim();
    }

    String copy(String key, int maximum) {
      final value = json.containsKey(key) ? json[key] : '';
      if (value is! String || value.length > maximum) {
        throw const FormatException('Invalid campaign block copy');
      }
      return value;
    }

    final type = json['type'];
    final presentation =
        json.containsKey('presentation') ? json['presentation'] : 'wide';
    if (type is! String ||
        !presentations.containsKey(type) ||
        !presentations[type]!.contains(presentation)) {
      throw const FormatException('Unsupported campaign block presentation');
    }
    final selected = json.containsKey('itemIds') ? json['itemIds'] : <String>[];
    if (selected is! List || selected.length > 12) {
      throw const FormatException('Too many campaign block items');
    }
    final itemIds = selected.map(identifier).toList(growable: false);
    if (itemIds.toSet().length != itemIds.length) {
      throw const FormatException('Duplicate campaign block items');
    }
    final enabled = json.containsKey('enabled') ? json['enabled'] : true;
    if (enabled is! bool) {
      throw const FormatException('Invalid block visibility');
    }
    final title = copy('title', 200), body = copy('body', 500);
    final image = json['image'];
    if (image != null && image is! String) {
      throw const FormatException('Invalid block image');
    }
    if (type == 'image' && (image == null || (image as String).isEmpty)) {
      throw const FormatException('Image banners need artwork');
    }
    if (type == 'text' && title.trim().isEmpty && body.trim().isEmpty) {
      throw const FormatException('Text blocks need copy');
    }
    final motion = json.containsKey('motion')
        ? CampaignMotion.fromJson(
            Map<String, dynamic>.from(json['motion'] as Map))
        : const CampaignMotion();
    if (type == 'text' &&
        !const ['none', 'fade', 'slide'].contains(motion.preset)) {
      throw const FormatException(
          'Text blocks support fade, slide, or no effect');
    }
    return CampaignBlock(
        id: identifier(json['id']),
        type: type,
        enabled: enabled,
        title: title,
        body: body,
        presentation: presentation as String,
        image: image as String?,
        destinationId: json['destinationId'] == null
            ? null
            : identifier(json['destinationId']),
        tabId: json['tabId'] == null ? null : identifier(json['tabId']),
        itemIds: itemIds,
        motion: motion);
  }
}

List<T> campaignBlockItems<T>(
    List<T> source, List<String> ids, String Function(T) idOf) {
  if (ids.isEmpty) return source;
  final byId = {for (final item in source) idOf(item): item};
  return ids.map((id) => byId[id]).whereType<T>().toList(growable: false);
}
