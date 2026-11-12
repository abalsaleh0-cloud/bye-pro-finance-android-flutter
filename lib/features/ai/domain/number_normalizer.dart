final class NumberNormalizer {
  const NumberNormalizer();
  static const Map<int, String> _digits = {
    0x0660:'0',0x0661:'1',0x0662:'2',0x0663:'3',0x0664:'4',
    0x0665:'5',0x0666:'6',0x0667:'7',0x0668:'8',0x0669:'9',
    0x06F0:'0',0x06F1:'1',0x06F2:'2',0x06F3:'3',0x06F4:'4',
    0x06F5:'5',0x06F6:'6',0x06F7:'7',0x06F8:'8',0x06F9:'9',
  };
  static const Map<String,int> _small = {
    'صفر':0,'واحد':1,'واحدة':1,'اثنان':2,'اثنين':2,'ثلاثة':3,
    'ثلاث':3,'أربعة':4,'اربعة':4,'خمسة':5,'خمس':5,'ستة':6,
    'ست':6,'سبعة':7,'سبع':7,'ثمانية':8,'ثمان':8,'تسعة':9,
    'تسع':9,'عشرة':10,'عشر':10,'أحد عشر':11,'اثنا عشر':12,
    'ثلاثة عشر':13,'أربعة عشر':14,'خمسة عشر':15,
  };
  static const Map<String,int> _tens = {
    'عشرين':20,'عشرون':20,'ثلاثين':30,'ثلاثون':30,'أربعين':40,
    'أربعون':40,'خمسين':50,'خمسون':50,'ستين':60,'ستون':60,
    'سبعين':70,'سبعون':70,'ثمانين':80,'ثمانون':80,'تسعين':90,'تسعون':90,
  };

  String normalizeDigits(String input) => String.fromCharCodes(
    input.runes.map((r) => _digits[r]?.codeUnitAt(0) ?? r),
  );

  String normalize(String input) => normalizeDigits(input);

  int? parseInteger(String input) {
    final value = normalizeDigits(input).trim();
    final numeric = int.tryParse(value.replaceAll(',', '').replaceAll('٬',''));
    if (numeric != null) return numeric;
    final tokens = value.replaceAll('خمسمئة',' خمسمئة ')
      .replaceAll('خمسمائة',' خمسمئة ').replaceAll('خمسمية',' خمسمئة ')
      .replaceAll('ألف',' ألف ').replaceAll('الف',' ألف ')
      .replaceAll('مائة',' مئة ').replaceAll('ألف و','ألف ').replaceAll('الف و','الف ').replaceAll('مئة و','مئة ').replaceAll('مائة و','مائة ')
      .replaceAll(RegExp(r'\s+'),' ').trim().split(' ')
      .where((e)=>e.isNotEmpty && e!='و');
    var total=0, group=0;
    for(final token in tokens) {
      if(token=='ألف' || token=='آلاف') { total+=(group==0?1:group)*1000; group=0; }
      else if(token=='ألفين') { total+=2000; }
      else if(token=='مئة' || token=='مية') { group+=100; }
      else if(token=='مئتين' || token=='ميتين') { group+=200; }
      else if(token=='خمسمئة') { group+=500; }
      else if(_small.containsKey(token)) { group+=_small[token]!; }
      else if(_tens.containsKey(token)) { group+=_tens[token]!; }
      else { return null; }
    }
    return total+group;
  }
}
