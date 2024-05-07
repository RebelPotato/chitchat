{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # elixir
    elixir_1_16 rebar3 elixir-ls clips
  ];
}