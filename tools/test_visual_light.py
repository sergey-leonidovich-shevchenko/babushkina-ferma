#!/usr/bin/env python3
"""Отрицательные сценарии паспорта VART-007."""
import copy
import json
import unittest
from visual_light import REPORT, contract_errors, verify


class LightTests(unittest.TestCase):
    def setUp(self):
        """Загружает независимую копию подтверждённых условий."""
        self.data=json.loads((REPORT/'light-profile.json').read_text())
        self.capture=json.loads((REPORT/'native/capture.json').read_text())

    def test_files(self):
        """Согласованные источники и нативные PNG проходят полную сверку."""
        self.assertEqual(verify(),[])

    def test_unconfirmed(self):
        """Отсутствие прямого выбора не превращается в приёмку."""
        self.data['decision_quote']=''
        self.assertIn('choice evidence',contract_errors(self.data,self.capture))

    def test_direction(self):
        """Солнце слева не допускает вторую левую падающую тень."""
        self.data['variants']['a']['cast']=[-.55,.25]
        self.assertIn('shadow direction',contract_errors(self.data,self.capture))

    def test_contact(self):
        """Одно пятно под серединой стола не заменяет контакты ножек."""
        self.data['parts'][2]['contact']=[[0,0,20,3]]
        self.assertIn('table foot contacts',contract_errors(self.data,self.capture))

    def test_missing_and_headless(self):
        """Потерянный режим, уменьшенный readback и headless отклоняются."""
        for mutation, expected in [('coverage','coverage'),('readback','readback'),('headless','native profile')]:
            capture=copy.deepcopy(self.capture)
            if mutation=='coverage':capture['frames'].pop()
            elif mutation=='readback':capture['frames'][0]['size']=[960,540]
            else:capture['display_server']='headless'
            self.assertIn(expected,contract_errors(self.data,capture))


if __name__=='__main__':unittest.main()
