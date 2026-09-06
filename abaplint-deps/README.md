# abaplint dependency stubs

Minimal stubs of SAP standard objects that the public abaplint dependency repository
(github.com/abaplint/deps) does not contain. They exist only so that the CI syntax check can
resolve the BAdI interface. They are not part of the solution and must never be installed in an
SAP system; abapGit ignores this folder because it lies outside `/src/`.
