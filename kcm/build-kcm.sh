#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "==> Building KCM Networkmanagement plugin..."

/usr/lib/qt6/moc -I/usr/include/KF6/KCMUtilsQuick -I/usr/include/KF6/KCMUtilsCore -I/usr/include/KF6/KCoreAddons -I/usr/include/qt6 -I/usr/include/qt6/QtCore kcm.h -o moc_kcm_h.cpp
/usr/lib/qt6/moc -I/usr/include/KF6/KCoreAddons -I/usr/include/qt6 -I/usr/include/qt6/QtCore kcm.cpp -o moc_kcm_cpp.cpp

/usr/lib/qt6/rcc -name kcm_networkmanagement kcm.qrc -o qrc_kcm.cpp

g++ -fPIC -shared ${CXXFLAGS:--O2} \
    -I. \
    -I/usr/include/qt6 \
    -I/usr/include/qt6/QtCore \
    -I/usr/include/qt6/QtGui \
    -I/usr/include/qt6/QtQml \
    -I/usr/include/qt6/QtQmlIntegration \
    -I/usr/include/qt6/QtQuick \
    -I/usr/include/KF6/KCMUtilsQuick \
    -I/usr/include/KF6/KCMUtilsCore \
    -I/usr/include/KF6/KCMUtils \
    -I/usr/include/KF6/KCoreAddons \
    -I/usr/include/KF6/KI18n \
    kcm.cpp qrc_kcm.cpp -o kcm_networkmanagement.so \
    ${LDFLAGS} \
    -lQt6Core -lQt6Qml -lQt6Quick -lKF6KCMUtilsQuick -lKF6KCMUtilsCore -lKF6CoreAddons -lKF6I18n

echo "==> Generating kcm_networkmanagement.desktop..."
/usr/lib/kf6/kcmdesktopfilegenerator kcm_networkmanagement.json kcm_networkmanagement.desktop

echo "==> KCM build completed successfully."
