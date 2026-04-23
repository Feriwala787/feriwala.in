{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    pkgs.awscli2
    pkgs.jdk17
    pkgs.git
  ];

  idx.extensions = [
    "Dart-Code.flutter"
    "Dart-Code.dart-code"
  ];

  idx.previews = {
    enable = true;
    previews = {
      android-customer = {
        command = [
          "flutter"
          "run"
          "--machine"
          "-d"
          "android"
        ];
        manager = "android";
        cwd = "feriwala_customer";
      };
      android-shop = {
        command = [
          "flutter"
          "run"
          "--machine"
          "-d"
          "android"
        ];
        manager = "android";
        cwd = "feriwala_shop";
      };
      android-delivery = {
        command = [
          "flutter"
          "run"
          "--machine"
          "-d"
          "android"
        ];
        manager = "android";
        cwd = "feriwala_delivery";
      };
    };
  };

  idx.workspace = {
    onCreate = {
      flutter-get-customer = "cd feriwala_customer && flutter pub get";
      flutter-get-shop = "cd feriwala_shop && flutter pub get";
      flutter-get-delivery = "cd feriwala_delivery && flutter pub get";
    };
    onStart = {
      flutter-get-customer = "cd feriwala_customer && flutter pub get";
    };
  };
}
