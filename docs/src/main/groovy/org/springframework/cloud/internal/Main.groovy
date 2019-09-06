package org.springframework.cloud.internal

import groovy.json.JsonSlurper
import groovy.transform.CompileStatic

import org.springframework.core.io.Resource
import org.springframework.core.io.support.PathMatchingResourcePatternResolver

/**
 * @author Marcin Grzejszczak
 */
class Main {

	@CompileStatic
	static void main(String... args) {
		String outputFile = args[0]
		new Main().generate(outputFile)
	}

	void generate(String outputFile) {
		println "Parsing all configuration metadata"
		Resource[] resources = new PathMatchingResourcePatternResolver()
				.getResources("classpath*:/META-INF/spring-configuration-metadata.json")
		println "Found [${resources.length}] configuration metadata jsons"
		TreeSet names = new TreeSet()
		def descriptions = [:]
		int count = 0
		resources.each { Resource resource ->
			if (resource.url.toString().contains("cloud")) {
				count++
				def slurper = new JsonSlurper()
				slurper.parseText(resource.inputStream.text).properties.each { val ->
					names.add val.name
					descriptions[val.name] = new ConfigValue(val.name, val.description, val.defaultValue)
				}
			}
		}
		println "Found [${count}] Cloud projects configuration metadata jsons"
		println "Successfully built the description table"
		if (names.empty) {
			println("Will not update the table, since no configuration properties were found!")
			return
		}
		new File(outputFile).text = """\
|===
|Name | Default | Description
${names.collect { it -> return descriptions[it] }.join("\n")}



|===
"""
		println "Successfully stored the output file"
	}

	@CompileStatic
	static class ConfigValue {
		String name
		String description
		Object defaultValue

		ConfigValue() {}

		ConfigValue(String name, String description, Object defaultValue) {
			this.name = name
			this.description = escapedValue(description)
			this.defaultValue = escapedValue(defaultValue)
		}

		private String escapedValue(Object value) {
			return value != null ?
					value.toString().replaceAll('\\|', '\\\\|') : ''
		}

		String toString() {
			"|${name} | ${defaultValue} | ${description}"
		}
	}
}
