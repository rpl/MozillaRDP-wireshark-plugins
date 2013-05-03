examples: examples/01-simulator-start.png examples/02-simulator-install-app.png examples/03-longStrings-simulator-remoteScratchpadPrototype.png

%.json: %.pcap
	OUT="$@" tshark -r $< -Xlua_script:RDPCollector.lua > /dev/null

%.png: %.json
	node RDPDiagramGenerator.js $< out.plantuml $@
	plantuml out.plantuml
	rm out.plantuml
