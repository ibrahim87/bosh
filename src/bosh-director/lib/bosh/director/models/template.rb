module Bosh::Director::Models
  class Template < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :release
    many_to_many :release_versions

    def validate
      validates_presence [:release_id, :name, :version, :blobstore_id, :sha1]
      validates_unique [:release_id, :name, :version]
      validates_format VALID_ID, [:name, :version]
    end

    def self.find_or_init_from_release_meta(release:, job_meta:, job_manifest:)
      template = first(
        name: job_meta['name'],
        release_id: release.id,
        fingerprint: job_meta['fingerprint'],
        version: job_meta['version']
      )

      if template
        template.sha1 = job_meta['sha1']
      else
        template ||= new(release_id: release.id, **job_meta.symbolize_keys)
      end

      template.package_names = parse_package_names(job_manifest)
      template.logs = job_manifest['logs']
      template.properties = job_manifest['properties']
      template.provides = job_manifest['provides'] if job_manifest['provides']
      template.consumes = job_manifest['consumes'] if job_manifest['consumes']
      template.templates = job_manifest['templates']

      template
    end

    def package_names
      object_or_nil(self.package_names_json)
    end

    def package_names=(packages)
      self.package_names_json = json_encode(packages)
    end

    def logs=(logs_spec)
      self.logs_json = json_encode(logs_spec)
    end

    def logs
      object_or_nil(self.logs_json)
    end

    # @param [Object] property_spec Property spec from job spec
    def properties=(property_spec)
      self.properties_json = json_encode(property_spec)
    end

    # @return [Hash] Template properties (as provided in job spec)
    # @return [nil] if no properties have been defined in job spec
    def properties
      object_or_nil(self.properties_json) || {}
    end

    def consumes=(consumes_spec)
      self.consumes_json = json_encode(consumes_spec)
    end

    def consumes
      object_or_nil(self.consumes_json)
    end

    def provides=(provides_spec)
      self.provides_json = json_encode(provides_spec)
    end

    def provides
      object_or_nil(self.provides_json)
    end

    def templates=(templates_spec)
      self.templates_json = json_encode(templates_spec)
    end

    def templates
      object_or_nil(self.templates_json)
    end

    def runs_as_errand?
      return false if self.templates == nil

      self.templates.values.include?('bin/run') ||
        self.templates.values.include?('bin/run.ps1')
    end

    private

    def object_or_nil(value)
      if value == 'null' || value == nil
        nil
      else
        JSON.parse(value)
      end
    end

    def json_encode(value)
      value.nil? ? 'null' : JSON.generate(value)
    end

    def self.parse_package_names(job_manifest)
      if job_manifest['packages'] && !job_manifest['packages'].is_a?(Array)
        raise Bosh::Director::JobInvalidPackageSpec, "Job '#{name}' has invalid package spec format"
      end
      job_manifest['packages'] || []
    end
  end
end
