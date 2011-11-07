package com.li.minimole.materials.agal
{

	import com.li.minimole.core.utils.ColorUtils;
	import com.li.minimole.core.vo.RGB;
	import com.li.minimole.materials.agal.methods.AGALPhongDiffuseMethod;
	import com.li.minimole.materials.agal.methods.AGALPhongSpecularMethod;
	import com.li.minimole.materials.agal.vo.mappings.RegisterMapping;
	import com.li.minimole.materials.agal.vo.registers.FragmentTemporary;
	import com.li.minimole.materials.agal.vo.registers.MatrixRegisterConstant;
	import com.li.minimole.materials.agal.vo.registers.RegisterConstant;
	import com.li.minimole.materials.agal.vo.registers.Temporary;
	import com.li.minimole.materials.agal.vo.registers.Varying;
	import com.li.minimole.materials.agal.vo.registers.VectorRegisterConstant;
	import com.li.minimole.materials.agal.vo.registers.VertexAttribute;
	import com.li.minimole.materials.agal.vo.registers.VertexTemporary;

	import flash.geom.Point;

	public class AGALPhongColorMaterial extends AGALMaterial
	{
		public function AGALPhongColorMaterial( color:uint = 0xFFFFFF ) {
			
			super();
			
			var rgb:RGB = ColorUtils.hexToRGB( color );

			// attributes
			var vertexPositions:VertexAttribute = addVertexAttribute( new VertexAttribute( "vertexPositions", VertexAttribute.POSITIONS ) ); // va0
			var vertexNormals:VertexAttribute = addVertexAttribute( new VertexAttribute( "vertexNormals", VertexAttribute.NORMALS ) ); // va1

			// vertex constants
			var mvc:RegisterConstant = addVertexConstant( new MatrixRegisterConstant( "modelViewProjection", null, new RegisterMapping( RegisterMapping.MVC_MAPPING ) ) ); // vc0 to vc3
			var transform:RegisterConstant = addVertexConstant( new MatrixRegisterConstant( "transform", null, new RegisterMapping( RegisterMapping.TRANSFORM_MAPPING ) ) ); // vc4 to vc7
			var reducedTransform:RegisterConstant = addVertexConstant( new MatrixRegisterConstant( "reducedTransform", null, new RegisterMapping( RegisterMapping.REDUCED_TRANSFORM_MAPPING ) ) ); // vc8 to vc11
			var lightPosition:VectorRegisterConstant = addVertexConstant( new VectorRegisterConstant( "lightPosition", 0, 0, 0, 0, new RegisterMapping( RegisterMapping.CAMERA_MAPPING ) ) ) as VectorRegisterConstant; // vc12
			var cameraPosition:VectorRegisterConstant = addVertexConstant( new VectorRegisterConstant( "cameraPosition", 0, 0, 0, 0, new RegisterMapping( RegisterMapping.CAMERA_MAPPING ) ) ) as VectorRegisterConstant; // vc13
			lightPosition.setComponentRanges( new Point( -5, 5 ), new Point( -5, 5 ), new Point( -5, 5 ), new Point( -5, 5 ) );
			cameraPosition.setComponentRanges( new Point( -5, 5 ), new Point( -5, 5 ), new Point( -5, 5 ), new Point( -5, 5 ) );

			// fragment constants
			var diffuseColor:VectorRegisterConstant = addFragmentConstant( new VectorRegisterConstant( "diffuseColor", rgb.r / 255, rgb.g / 255, rgb.b / 255, rgb.a ) ) as VectorRegisterConstant;
			var specularColor:VectorRegisterConstant = addFragmentConstant( new VectorRegisterConstant( "specularColor", 1, 1, 1, 1 ) ) as VectorRegisterConstant;
			var lightProperties:VectorRegisterConstant = addFragmentConstant( new VectorRegisterConstant( "lightProperties", 0, 1, 0.5, 50 ) ) as VectorRegisterConstant;
			diffuseColor.setComponentNames( "red", "green", "blue", "alpha" );
			specularColor.setComponentNames( "red", "green", "blue", "alpha" );
			lightProperties.setComponentNames( "ambient", "diffuse", "specular", "gloss" );
			lightProperties.compRanges[ 3 ] = new Point( 0, 100 );

			// varying
			var interpolatedDirToLight:Varying = addVarying( new Varying( "interpolatedDirToLight" ) );
			var interpolatedDirToCamera:Varying = addVarying( new Varying( "interpolatedDirToCamera" ) );
			var interpolatedNormals:Varying = addVarying( new Varying( "interpolatedNormals" ) );

			// vertex agal
			_currentAGAL = "";
			var sceneSpaceVertexPosition:Temporary = addTemporary( new VertexTemporary( "sceneSpaceVertexPosition" ) );
			m44( sceneSpaceVertexPosition, vertexPositions, transform, "calculate vertex positions in scene space" );
			sub( interpolatedDirToLight, lightPosition, sceneSpaceVertexPosition, "interpolate direction to light" );
			sub( interpolatedDirToCamera, cameraPosition, sceneSpaceVertexPosition, "interpolate direction to camera" );
			m44( interpolatedNormals, vertexNormals, reducedTransform, "interpolate normal positions in scene space (ignoring position)" );
			m44( op, vertexPositions, mvc, "output position to clip space" );
			vertexAGAL = _currentAGAL;

			// fragment agal
			_currentAGAL = "";
			// normalize input
			var normalizedDirToLight:Temporary = addTemporary( new FragmentTemporary( "normalizedDirToLight" ) );
			nrm( normalizedDirToLight.xyz, interpolatedDirToLight, "normalize dir to light" );
			var normalizedDirToCamera:Temporary = addTemporary( new FragmentTemporary( "normalizedDirToCamera" ) );
			nrm( normalizedDirToCamera.xyz, interpolatedDirToCamera, "normalize dir to camera" );
			var normalizedNormal:Temporary = addTemporary( new FragmentTemporary( "normalizedNormal" ) );
			nrm( normalizedNormal.xyz, interpolatedNormals, "normalize normals" );
			// calculate diffuse term
			var diffuseTerm:Temporary = new AGALPhongDiffuseMethod(
					this,
					normalizedNormal,
					normalizedDirToLight,
					lightProperties,
					diffuseColor
			).diffuseTerm;
			// calculate specular term
			var specularTerm:Temporary = new AGALPhongSpecularMethod(
					this,
					normalizedNormal,
					normalizedDirToLight,
					normalizedDirToCamera,
					lightProperties,
					specularColor
			).specularTerm;
			// output
			var combinedTerms:Temporary = addTemporary( new FragmentTemporary( "combinedTerms" ) );
			add( combinedTerms.xyz, diffuseTerm.xyz, specularTerm.xyz, "combine diffuse + specular" );
			mov( oc, combinedTerms.xyz );
			fragmentAGAL = _currentAGAL;
		}
	}
}
