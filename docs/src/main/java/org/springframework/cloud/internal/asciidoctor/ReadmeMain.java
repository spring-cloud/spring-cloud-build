/*
 * Copyright 2012-2020 the original author or authors.
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

package org.springframework.cloud.internal.asciidoctor;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

import org.asciidoctor.Asciidoctor;
import org.asciidoctor.Attributes;
import org.asciidoctor.Options;
import org.asciidoctor.SafeMode;

public class ReadmeMain {
	public static void main(String... args) {
		File inputFile = new File(args[0]);
		File outputFile = new File(args[1]);
		System.out.println("Will do the Readme conversion from [" + inputFile + "] to [" + outputFile + "]");
		if (!inputFile.exists()) {
			System.out.println("There's no file [" + inputFile + "], skipping readme generation");
			return;
		}
		new ReadmeMain().convert(inputFile, outputFile);
	}

	void convert(File input, File output) {
		Asciidoctor asciidoctor = Asciidoctor.Factory.create();
		asciidoctor.javaExtensionRegistry().preprocessor(new CoalescerPreprocessor(output));
		Options options = options(input, output);
		try {
			String fileAsString = new String(Files.readAllBytes(input.toPath()));
			asciidoctor.convert(fileAsString, options);
			System.out.println("Successfully converted the Readme file!\n");
		} catch (IOException ex) {
			throw new IllegalStateException("Failed to convert the file", ex);
		}
	}

	private Options options(File input, File output) {
		Attributes attributes = Attributes.builder()
				.allowUriRead(true)
				.attribute("project-root", output.getParent())
				.build();

		return Options.builder()
				.sourceDir(input.getParentFile())
				.baseDir(input.getParentFile())
				.attributes(attributes)
				.safe(SafeMode.UNSAFE)
				.parseHeaderOnly(true)
				.build();
	}
}
