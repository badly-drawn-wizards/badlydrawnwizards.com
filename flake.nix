{
  description = "badlydrawnwizards.com, a Verso blog";

  inputs = {
    lean4-nix.url = "github:lenianiva/lean4-nix";
    nixpkgs.follows = "lean4-nix/nixpkgs";
  };

  outputs = { nixpkgs, lean4-nix, ... }:
    let
      systems = [ "aarch64-linux" "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        overlays = [ (lean4-nix.readToolchainFile ./lean-toolchain) ];
      }));
    in
    {
      packages = forAll (pkgs:
        let
          lake2nix = pkgs.callPackage lean4-nix.lake { };
          manifest = pkgs.lib.importJSON ./lake-manifest.json;
          pinned = name: pkgs.lib.findFirst (p: p.name == name) null manifest.packages;

          # Builds these libraries' shared/static facets, which a read-only
          # dependency needs; lake2nix only guesses the capitalised package name.
          buildLibs = libs: {
            buildPhase = ''
              runHook preBuild
              lake build ${pkgs.lib.concatMapStringsSep " " (l: "${l}:shared ${l}:static") libs}
              runHook postBuild
            '';
          };

          # subverso has no dependencies and so no lake-manifest.json, which
          # lake2nix requires; give it an empty one.
          subverso = lake2nix.mkLakeDerivation ({
            name = "subverso";
            src = pkgs.runCommand "subverso-src" { } ''
              cp -r ${builtins.fetchGit { inherit (pinned "subverso") url rev; shallow = true; }} $out
              chmod +w $out
              echo '{"version": "1.1.0", "packagesDir": ".lake/packages", "packages": [], "name": "subverso", "lakeDir": ".lake"}' > $out/lake-manifest.json
            '';
          } // buildLibs [ "SubVerso" ]);

          # Dependencies come from lake-manifest.json, each fetched at its
          # pinned rev; the build itself has no network.
          generator = lake2nix.mkPackage {
            name = "generate-blog";
            src = ./.;
            depOverrideDeriv = { inherit subverso; };
            depOverride.verso = buildLibs [ "VersoUtil" "Verso" "MultiVerso" "VersoSearch" "VersoBlog" ];
          };
        in
        {
          inherit generator;
          # The static site.
          default = pkgs.runCommand "badlydrawnwizards.com" { } ''
            ${generator}/bin/generate-blog --output $out
          '';
        });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell { packages = [ pkgs.lean.lean-all ]; };
      });
    };
}
