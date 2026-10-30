import 'package:flutter_test/flutter_test.dart';

import '../../tool/license_report.dart';

void main() {
  group('classifyLicense', () {
    test('MIT', () {
      expect(
        classifyLicense('MIT License\n\nPermission is hereby granted, free of '
            'charge, to any person obtaining a copy'),
        'MIT',
      );
    });

    test('BSD-3-Clause has the "neither the name" clause', () {
      expect(
        classifyLicense('Redistribution and use in source and binary forms, '
            'with or without modification, are permitted...\n'
            '    * Neither the name of Google Inc. nor the names of its\n'
            'contributors may be used to endorse or promote products'),
        'BSD-3-Clause',
      );
    });

    test('BSD-2-Clause lacks the third clause', () {
      expect(
        classifyLicense('Redistribution and use in source and binary forms, '
            'with or without modification, are permitted provided that the '
            'following conditions are met: 1. ... 2. ...'),
        'BSD-2-Clause',
      );
    });

    test('Apache-2.0', () {
      expect(
        classifyLicense('                                 Apache License\n'
            '                           Version 2.0, January 2004'),
        'Apache-2.0',
      );
    });

    test('MPL-2.0 wins even though it mentions the GNU licenses', () {
      expect(
        classifyLicense('Mozilla Public License Version 2.0\n'
            '"Secondary License" means either the GNU General Public License, '
            'Version 2.0, the GNU Lesser General Public License, Version 2.1, '
            'the GNU Affero General Public License, Version 3.0'),
        'MPL-2.0',
      );
    });

    test('LGPL before GPL', () {
      expect(
        classifyLicense('GNU LESSER GENERAL PUBLIC LICENSE\nVersion 3 ... '
            'the GNU General Public License'),
        'LGPL',
      );
    });

    test('GPL', () {
      expect(
        classifyLicense('GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007'),
        'GPL',
      );
    });

    test('AGPL before GPL', () {
      expect(
        classifyLicense('GNU AFFERO GENERAL PUBLIC LICENSE\nVersion 3 ... '
            'the GNU General Public License'),
        'AGPL',
      );
    });

    test('OFL-1.1', () {
      expect(
        classifyLicense('This Font Software is licensed under the SIL Open '
            'Font License, Version 1.1.\nSIL OPEN FONT LICENSE Version 1.1'),
        'OFL-1.1',
      );
    });

    test('Syncfusion', () {
      expect(
        classifyLicense('Syncfusion<sup>&reg;</sup> License\n\nSyncfusion '
            'Flutter Core package ... Syncfusion Community License Program'),
        'LicenseRef-Syncfusion',
      );
    });

    test('unknown', () {
      expect(classifyLicense('All rights reserved. Do not copy.'), 'UNKNOWN');
      expect(classifyLicense(''), 'UNKNOWN');
    });
  });
}
