from pathlib import Path
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()
if 'com.dinnermap' not in s:
    redirect='''            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="com.dinnermap" android:host="auth-callback" />
            </intent-filter>
'''
    s=s.replace('        </activity>',redirect+'        </activity>')
s=s.replace('android:label="dinnermap"','android:label="DinnerMap"')
if 'android.permission.INTERNET' not in s:
    s=s.replace('    <application', '    <uses-permission android:name="android.permission.INTERNET" />\n    <application')
p.write_text(s)
