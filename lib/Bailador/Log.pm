use v6.c;

unit module Bailador::Log;

use Bailador::Configuration;
use Bailador::Log::Formatter;
use Bailador::Log::Adapter;

use Log::Any;
use URI;

sub init( Bailador::Configuration:D :$config!, Log::Any::Adapter:D :$p6w-adapter! ) is export {
  my @filter    = $config.log-filter;
  my $formatter = Bailador::Log::Formatter.new(
      format   => $config.log-format,
      colorize => $config.terminal-color,
      colors   => {
          trace     =>  $config.terminal-color-trace,
          debug     =>  $config.terminal-color-debug,
          info      =>  $config.terminal-color-info,
          notice    =>  $config.terminal-color-notice,
          warning   =>  $config.terminal-color-warning,
          error     =>  $config.terminal-color-error,
          critical  =>  $config.terminal-color-critical,
          alert     =>  $config.terminal-color-alert,
          emergency =>  $config.terminal-color-emergency,
      },
  );
  # https://github.com/jsimonet/log-any/issues/1
  # black magic to increase the logging speed
  Log::Any.add( Log::Any::Pipeline.new(), :overwrite );

  # Configure logs
  for $config.logs {
    my $log-output = $_.key;
    my $log-config = $_.value;

    my $log-output-uri = URI.new( $log-output );
    my $adapter;
    my $colorize = False; # Set to config.terminal-color value if output is a terminal
    given $log-output-uri.scheme {
      when 'terminal' {
        given $log-output-uri.path {
          when 'stdout' {
            use Log::Any::Adapter::Stdout;
            $adapter = Log::Any::Adapter::Stdout.new;
          }
          when 'stderr' {
            use Log::Any::Adapter::Stderr;
            $adapter = Log::Any::Adapter::Stderr.new;
          }
          default { die "Invalid path ($_) for \"terminal\" scheme. Please use one of \"stdout\" or \"stderr\"."; }
        }
        $colorize = $config.terminal-color;
      }
      when 'file' {
        use Log::Any::Adapter::File;
        $adapter = Log::Any::Adapter::File.new( :path($log-output-uri.path.Str) );
      }
      when 'p6w' {
        given $log-output-uri.path {
          when 'errors' {
            # my $app = app();
            $adapter = $p6w-adapter;
          }
        }
      }
      default { die "Invalid scheme ($log-output). Please use one of \"terminal\", \"file\" or \"p6w\"." }
    }

    # Check filters
    my @filters;

    # Template filters
    with $log-config{'template-filter'} {
      when 'http-requests' {
        @filters.push( 'category' => 'request' );
      }
      when 'templates' {
        @filters.push( 'category' => 'templates' );
      }
      when 'request-error' {
        @filter.push( 'category' => 'request-error', 'severity' => 'error' );
      }
    }

    # Manual filters
    if $log-config{'category'} -> $category {
      @filters.push( 'category' => $category );
    }

    if $log-config{'severity'} -> $severity {
      @filters.push( 'severity' => $severity );
    }

    Log::Any.add( $adapter,
      :formatter(
        Bailador::Log::Formatter.new(
          format => $log-config<format> // Nil,
          template-format => $log-config<template-format> // Nil,
          colorize => $colorize,
          colors   => {
            trace     =>  $config.terminal-color-trace,
            debug     =>  $config.terminal-color-debug,
            info      =>  $config.terminal-color-info,
            notice    =>  $config.terminal-color-notice,
            warning   =>  $config.terminal-color-warning,
            error     =>  $config.terminal-color-error,
            critical  =>  $config.terminal-color-critical,
            alert     =>  $config.terminal-color-alert,
            emergency =>  $config.terminal-color-emergency,
          }
        )
      ),
      :filter( @filters ),
      :continue-on-match,
    );
  }

}
