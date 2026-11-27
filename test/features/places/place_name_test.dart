import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/places/domain/place_name.dart';

void main() {
  PlaceName clean(String raw) => cleanName(raw);

  group('case', () {
    test('a shouted name is set in title case', () {
      expect(
        clean('RESTORAN CHE ABANG KARI KEPALA IKAN FAMOUS PENANG').title,
        'Restoran Che Abang Kari Kepala Ikan Famous Penang',
      );
    });

    test('a flat lowercase name is set in title case', () {
      expect(clean('feinschmecker cafe').title, 'Feinschmecker Cafe');
    });

    test('short forms, Hj and D\' keep their own shape', () {
      expect(clean('KFC BBQ SP').title, 'KFC BBQ SP');
      expect(clean('HJ SHUIB LAKSA').title, 'Hj Shuib Laksa');
      expect(clean("D'AIZY COTTAGE").title, "D'Aizy Cottage");
      expect(clean('WARUNG MEE UDANG 12EKOR').title, 'Warung Mee Udang 12ekor');
    });

    test('Mr, Kg and initials such as US and AA are written one way', () {
      expect(clean('MR CHURROS (Penaga)').title, 'Mr Churros');
      expect(clean('US PIZZA - BERTAM').title, 'US Pizza');
      expect(clean('AA MAN CAFE2').title, 'AA Man Cafe2');
      expect(
        clean('WARONG AKAK PORT GULAI KG SELAMAT').title,
        'Warong Akak Port Gulai Kg Selamat',
      );
      expect(clean('OVR.ROAST EATERY').title, 'Ovr.Roast Eatery');
      expect(
        clean('PENYETPENYET.COM SUNWAY CARNIVAL').title,
        'Penyetpenyet.com Sunway Carnival',
      );
    });

    test('a name in capitals but for a word counts as shouted', () {
      expect(
        clean('LI SARJAN NASI BURUNG Puyuh (BARU)').title,
        'Li Sarjan Nasi Burung Puyuh',
      );
    });

    test('small joining words stay lowercase inside a name', () {
      expect(
        clean('KEDAI MAKANAN DAN MINUMAN AH CHAI').title,
        'Kedai Makanan dan Minuman Ah Chai',
      );
    });

    test('a name already in mixed case is left as its owner wrote it', () {
      expect(clean("McDonald's Bertam").title, "McDonald's Bertam");
      expect(clean('OVR.Roast Eatery').title, 'OVR.Roast Eatery');
    });
  });

  group('places and extras', () {
    test('a place after a separator goes', () {
      expect(
        clean('Elfinia Cafe • Big Screen • Kepala Batas • Penang').title,
        'Elfinia Cafe',
      );
      expect(clean('Baeshake Cafe | Bertam, Penang').title, 'Baeshake Cafe');
      expect(
        clean('Mykori Dessert Cafe - Kepala Batas').title,
        'Mykori Dessert Cafe',
      );
      expect(
        clean('Gerai Bihun Sup Che Ta, Kampung Padang').title,
        'Gerai Bihun Sup Che Ta',
      );
    });

    test('a name that is only "Kedai Makan" keeps the part after it', () {
      expect(
        clean('Kedai Makan, Kampung Mengkuang Mak sulong').title,
        'Kedai Makan, Kampung Mengkuang Mak sulong',
      );
    });

    test('a bracket never closed is treated like one that is', () {
      expect(
        clean('WZ PASEMBOR KODIANG PDG SERAI ( CAWANGAN TAMAN SELASIH').title,
        'WZ Pasembor Kodiang Pdg Serai',
      );
    });

    test('a slash joins two names rather than cutting one off', () {
      expect(
        clean('Hassan / Abah Roti Canai').title,
        'Hassan / Abah Roti Canai',
      );
      expect(clean('Gerai MPSP 3/4').title, 'Gerai MPSP 3/4');
      expect(clean('Wu Ji Restaurant/ 伍季砂锅黄焖鸡').title, 'Wu Ji Restaurant');
    });

    test('a place that is part of the name stays', () {
      expect(
        clean('Kopi Saigon Pokok Sena Penang').title,
        'Kopi Saigon Pokok Sena Penang',
      );
    });

    test('brackets holding a place, a branch, a menu or a number go', () {
      expect(
        clean('Aisyah Nasi Ayam (Cawangan Kepala Batas)').title,
        'Aisyah Nasi Ayam',
      );
      expect(
        clean('Pagi Senja Kopitiam (Bertam)').title,
        'Pagi Senja Kopitiam',
      );
      expect(
        clean('Gerai Kak Na (Laksa, Mee Udang dll)').title,
        'Gerai Kak Na',
      );
      expect(
        clean("D'Fiesha Licious Steamboat&Grill (PG0424936-K)").title,
        "D'Fiesha Licious Steamboat&Grill",
      );
    });

    test('brackets holding another name for the place stay', () {
      expect(
        clean('Gepuk Supaicy (Alang Fried Chicken)').title,
        'Gepuk Supaicy (Alang Fried Chicken)',
      );
      expect(
        clean('Mode crispy burger (MCB)').title,
        'Mode crispy burger (MCB)',
      );
    });

    test('company suffixes go', () {
      expect(
        clean('Dai You Bin Restaurant Sdn. Bhd.').title,
        'Dai You Bin Restaurant',
      );
      expect(
        clean('River Palace Seafood Restaurant (M) SDN BHD').title,
        'River Palace Seafood Restaurant',
      );
    });
  });

  group('other scripts and odd characters', () {
    test('a name in two scripts splits into title and other', () {
      final PlaceName n = clean('Union Cafe 友联茶室');
      expect(n.title, 'Union Cafe');
      expect(n.other, '友联茶室');
    });

    test('the other script may come first, with a place after', () {
      final PlaceName n = clean('阿金饭店 Kedai Kopi Ah Kim (Kepala Batas)');
      expect(n.title, 'Kedai Kopi Ah Kim');
      expect(n.other, '阿金饭店');
    });

    test('a menu note in the other script is dropped with its brackets', () {
      final PlaceName n = clean(
        'Thai Ka Seafood Restaurant @ Penang Kepala Batas 大家海鲜饮食中心 '
        '(早市烧腊鸡饭/晚市海鲜煮炒)',
      );
      expect(n.title, 'Thai Ka Seafood Restaurant');
      expect(n.other, '大家海鲜饮食中心');
    });

    test('a Latin name only in brackets loses the brackets', () {
      final PlaceName n = clean('大快饭店 (Restaurant Tar Kuow)');
      expect(n.title, 'Restaurant Tar Kuow');
      expect(n.other, '大快饭店');
    });

    test('full-width and mismatched brackets are read as brackets', () {
      expect(
        clean('Thai Dee 小泰皇 （Thai Restaurant)').title,
        'Thai Dee (Thai Restaurant)',
      );
      expect(
        clean(
          '甲子园 Koshien Yakitori Japanese Bar & Restaurant (Butterworth）',
        ).title,
        'Koshien Yakitori Japanese Bar & Restaurant',
      );
    });

    test('initials before a separator are not taken for the name', () {
      final PlaceName n = clean('S P. 加国饭店@Restaurant Jiakok');
      expect(n.title, 'Restaurant Jiakok');
      expect(n.other, '加国饭店');
    });

    test('a name with no Latin letters is shown as it is', () {
      final PlaceName n = clean('檳檳東炎麵');
      expect(n.title, '檳檳東炎麵');
      expect(n.other, isNull);
      expect(clean('老姨面档（住家式）').title, '老姨面档（住家式）');
    });

    test('emoji go and fancy letters become plain ones', () {
      expect(clean('每日汉堡🍔').title, '每日汉堡');
      expect(
        clean('𝑲𝒆𝒅𝒂𝒊 𝑴𝒂𝒌𝒂𝒏 𝑩𝒐𝒚𝒐𝒕').title,
        'Kedai Makan Boyot',
      );
    });

    test('a name that would clean to nothing is kept as Google has it', () {
      expect(clean('.').title, '.');
      expect(clean('(Bertam)').title, '(Bertam)');
    });
  });
}
