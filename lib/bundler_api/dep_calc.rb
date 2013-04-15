require 'zlib'
require_relative '../bundler_api'

class BundlerApi::DepCalc
  DepKey = Struct.new(:name, :number, :platform)

  # @param [String] array of strings with the gem names
  def self.deps_for(connection, gems)
    dataset = connection[<<-SQL, Sequel.value_list(gems)]
      SELECT rv.name, rv.number, rv.platform, d.requirements, for_dep_name.name dep_name
      FROM
        (SELECT r.name, v.number, v.platform, v.id AS version_id
        FROM rubygems AS r, versions AS v
        WHERE v.rubygem_id = r.id
          AND v.indexed is true
          AND r.name IN ?) AS rv
      LEFT JOIN dependencies AS d ON
        d.version_id = rv.version_id
      LEFT JOIN rubygems AS for_dep_name ON
        d.rubygem_id = for_dep_name.id
        AND d.scope = 'runtime';
SQL

    deps = {}
    dataset.each do |row|
      key = DepKey.new(row[:name], row[:number], row[:platform])
      deps[key] = [] unless deps[key]
      deps[key] << [row[:dep_name], row[:requirements]] if row[:dep_name]
    end

    deps.map do |dep_key, gem_deps|
      {
        name:         dep_key.name,
        number:       dep_key.number,
        platform:     dep_key.platform,
        dependencies: gem_deps
      }
    end
  end
end
