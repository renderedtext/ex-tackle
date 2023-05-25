# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

if Mix.env() == :test do
  config :junit_formatter,
    report_dir: "/tmp/out",
    report_file: "results.xml",
    # Adds information about file location when suite finishes
    print_report_file: true,
    # Include filename and file number for more insights
    include_filename?: true,
    include_file_line?: true,
    automatic_create_dir?: true
end
