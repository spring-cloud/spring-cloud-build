/*
 * Copyright 2013-2019 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.springframework.cloud.internal;

import java.io.File;
import java.io.IOException;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.Files;

import org.junit.jupiter.api.Test;

import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;

import static org.assertj.core.api.BDDAssertions.then;

class GeneratorTests {

	URL root = GeneratorTests.class.getResource(".");

	@Test
	void should_not_create_a_file_when_no_properties_were_found()
			throws URISyntaxException {
		Main.Generator generator = new Main.Generator() {
			@Override
			protected Resource[] getResources() {
				return new Resource[0];
			}
		};
		File file = new File(root.toURI().toString(), "output.adoc");
		String inclusionPattern = ".*";

		generator.generate(file.getAbsolutePath(), inclusionPattern);

		then(file).doesNotExist();
	}

	@Test
	void should_create_a_file_when_cloud_file_was_found() {
		Main.Generator generator = new Main.Generator() {
			@Override
			protected Resource[] getResources() {
				return new Resource[] { resource("/not-matching-name.json"),
						resource("/with-cloud-in-name.json") };
			}

			@Override
			protected boolean resourceNameContainsPattern(Resource resource) {
				try {
					return resource.getURI().toString().contains("with-cloud");
				}
				catch (IOException ex) {
					throw new IllegalStateException(ex);
				}
			}
		};
		File file = new File(root.getFile().toString(), "output.adoc");
		String inclusionPattern = ".*";

		generator.generate(file.getAbsolutePath(), inclusionPattern);

		then(file).exists();
		then(asString(file)).contains("spring.first-property")
				.contains("unmatched.second-property")
				.doesNotContain("example1.first-property");
	}

	@Test
	void should_create_a_file_when_spring_property_was_found() {
		Main.Generator generator = new Main.Generator() {
			@Override
			protected Resource[] getResources() {
				return new Resource[] { resource("/not-matching-name.json"),
						resource("/with-cloud-in-name.json") };
			}
		};
		File file = new File(root.getFile().toString(), "output.adoc");
		String inclusionPattern = "spring.*";

		generator.generate(file.getAbsolutePath(), inclusionPattern);

		then(file).exists();
		then(asString(file)).contains("spring.first-property")
				.doesNotContain("example1.first-property")
				.doesNotContain("unmatched.second-property");
	}

	static String asString(File file) {
		try {
			return new String(Files.readAllBytes(file.toPath()));
		}
		catch (IOException ex) {
			throw new IllegalStateException(ex);
		}
	}

	static Resource resource(String path) {
		return new FileSystemResource(GeneratorTests.class.getResource(path).getFile());
	}

}
