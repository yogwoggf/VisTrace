#include "TraceResult.h"

#include "glm/gtx/compatibility.hpp"

int TraceResult::id = -1;

// Ray Tracing Gems
inline float TriUVInfoToTexLOD(const VTFTexture* pTex, glm::vec2 uvInfo)
{
	return uvInfo.x + 0.5f * log2(pTex->GetWidth() * pTex->GetHeight() * uvInfo.y);
}

TraceResult::TraceResult(
	const glm::vec3& direction, float distance,
	float coneWidth, float coneAngle,
	const Triangle& tri, const TriangleData& triData,
	const glm::vec2& uv,
	const Entity& ent, const Material& mat
) :
	distance(distance),
	coneWidth(coneWidth), coneAngle(coneAngle), mipOverride(coneWidth < 0.f || coneAngle <= 0.f),
	materialFlags(mat.flags), surfaceFlags(mat.surfFlags), maskedBlending(mat.maskedBlending),
	baseTexture(mat.baseTexture), baseTexMat(mat.baseTexMat), mrao(mat.mrao),
	baseTexture2(mat.baseTexture2), baseTexMat2(mat.baseTexMat2), mrao2(mat.mrao2),
	blendTexture(mat.blendTexture), blendTexMat(mat.blendTexMat)
{
	if (!triData.ignoreNormalMap) {
		normalMap = mat.normalMap;
		normalMapMat = mat.normalMapMat;
		normalMap2 = mat.normalMap2;
		normalMapMat2 = mat.normalMapMat2;
	}

	wo = -direction;

	for (int i = 0; i < 3; i++) {
		vN[i] = triData.normals[i];
		vT[i] = triData.tangents[i];
		vB[i] = triData.binormals[i];
		vUV[i] = triData.uvs[i];
	}

	v[0] = glm::vec3(tri.p0[0], tri.p0[1], tri.p0[2]);
	Vector3 p1 = tri.p1(), p2 = tri.p2();
	v[1] = glm::vec3(p1[0], p1[1], p1[2]);
	v[2] = glm::vec3(p2[0], p2[1], p2[2]);

	uvw = glm::vec3(uv, 1.f - uv[0] - uv[1]);
	geometricNormalWorld = glm::vec3(tri.n[0], tri.n[1], tri.n[2]);
	geometricNormal = glm::normalize(geometricNormalWorld);

	blendFactor = uvw.z * triData.alphas[0] + uvw.x * triData.alphas[1] + uvw.y * triData.alphas[2];
	texUV = uvw[2] * vUV[0] + uvw[0] * vUV[1] + uvw[1] * vUV[2];

	entIdx = ent.id;
	rawEnt = ent.rawEntity;
	submatIdx = triData.submatIdx;

	albedo = ent.colour * mat.colour;
	alpha = ent.colour.a * mat.colour.a;

	hitSky = (surfaceFlags & BSPEnums::SURF::SKY) != BSPEnums::SURF::NONE;
	hitWater = mat.water;

	frontFacing = glm::dot(wo, geometricNormal) >= 0.f;
}

// Ray Tracing Gems
void TraceResult::CalcFootprint()
{
	if (textureLodSet || mipOverride) return;
	using namespace glm;

	// Propagate cone given input parameters from starting width and angle to hit point
	coneWidth = coneAngle * distance + coneWidth;

	vec2 uv10 = vUV[1] - vUV[0];
	vec2 uv20 = vUV[2] - vUV[0];
	float triUVArea = abs(uv10.x * uv20.y - uv20.x * uv10.y);

	float triLoDOffset = 0.5f * log2(triUVArea / length(geometricNormalWorld));
	float normalTerm = dot(wo, geometricNormal);

	textureLodInfo = glm::vec2(
		triLoDOffset,
		(coneWidth * coneWidth) / (normalTerm * normalTerm)
	);
	textureLodSet = true;
}

void TraceResult::CalcBlendFactor()
{
	if (blendFactorSet) return;

	if (maskedBlending) blendFactor = 0.5f;
	if (blendTexture != nullptr) {
		CalcFootprint();

		glm::vec2 scaled = blendTexMat * texUV;
		VTFPixel pixelBlend = blendTexture->Sample(
			scaled.x, scaled.y,
			mipOverride ? 0 : TriUVInfoToTexLOD(blendTexture, textureLodInfo)
		);

		if (maskedBlending) {
			blendFactor = pixelBlend.g;
		} else {
			float minb = glm::saturate(pixelBlend.g - pixelBlend.r);
			float maxb = glm::saturate(pixelBlend.g + pixelBlend.r);
			blendFactor = glm::smoothstep(minb, maxb, blendFactor);
		}
	}

	blendFactorSet = true;
}

void TraceResult::CalcTBN()
{
	if (tbnSet) return;

	normal = uvw[2] * vN[0] + uvw[0] * vN[1] + uvw[1] * vN[2];
	tangent = uvw[2] * vT[0] + uvw[0] * vT[1] + uvw[1] * vT[2];
	binormal = uvw[2] * vB[0] + uvw[0] * vB[1] + uvw[1] * vB[2];

	if (normalMap != nullptr) {
		CalcFootprint();
		CalcBlendFactor();

		glm::vec2 scaled = normalMapMat * texUV;
		VTFPixel pixelNormal = normalMap->Sample(
			scaled.x, scaled.y,
			mipOverride ? 0 : TriUVInfoToTexLOD(normalMap, textureLodInfo)
		);
		glm::vec3 mappedNormal = glm::vec3(pixelNormal.r, pixelNormal.g, pixelNormal.b) * 2.f - 1.f;

		if (normalMap2 != nullptr) {
			scaled = normalMapMat2 * texUV;
			pixelNormal = normalMap2->Sample(
				scaled.x, scaled.y,
				mipOverride ? 0 : TriUVInfoToTexLOD(normalMap2, textureLodInfo)
			);
			glm::vec3 mappedNormal2 = glm::vec3(pixelNormal.r, pixelNormal.g, pixelNormal.b) * 2.f - 1.f;

			mappedNormal = glm::normalize(glm::lerp(mappedNormal, mappedNormal2, blendFactor));
		}

		normal = glm::mat3{
			tangent[0],  tangent[1],  tangent[2],
			binormal[0], binormal[1], binormal[2],
			normal[0],   normal[1],   normal[2]
		} * mappedNormal;
		normal = glm::normalize(normal);

		tangent = glm::normalize(tangent - normal * glm::dot(tangent, normal));
		binormal = glm::cross(tangent, normal);
	}

	if (!frontFacing) {
		normal = -normal;
	}

	glm::vec3 Ng = frontFacing ? geometricNormal : -geometricNormal;
	glm::vec3 Ns = normal;

	const float kCosThetaThreshold = 0.1f;
	float cosTheta = glm::dot(wo, Ns);
	if (cosTheta <= kCosThetaThreshold) {
		float t = glm::saturate(cosTheta * (1.f / kCosThetaThreshold));
		normal = glm::normalize(glm::lerp(Ng, Ns, t));

		tangent = glm::normalize(tangent - normal * glm::dot(tangent, normal));
		binormal = glm::cross(tangent, normal);
	}

	tbnSet = true;
}

void TraceResult::CalcShadingData()
{
	if (shadingDataSet) return;
	CalcFootprint();
	CalcBlendFactor();

	// Cache the scaled textures for both here cause we might use them again on the MRAO
	glm::vec2 scaled = baseTexMat * texUV;
	glm::vec2 scaled2 = baseTexMat2 * texUV;

	VTFPixel pixelColour = baseTexture->Sample(
		scaled.x, scaled.y,
		mipOverride ? 0 : TriUVInfoToTexLOD(baseTexture, textureLodInfo)
	);
	glm::vec4 colour(pixelColour.r, pixelColour.g, pixelColour.b, pixelColour.a);

	if (baseTexture2 != nullptr) {
		pixelColour = baseTexture2->Sample(
			scaled2.x, scaled2.y,
			mipOverride ? 0 : TriUVInfoToTexLOD(baseTexture2, textureLodInfo)
		);
		glm::vec4 colour2(pixelColour.r, pixelColour.g, pixelColour.b, pixelColour.a);

		colour = glm::lerp(colour, colour2, blendFactor);
	}

	albedo *= glm::vec3(colour.r, colour.g, colour.b);
	alpha *= colour.a;

	if (mrao != nullptr) {
		VTFPixel pixelMRAO = mrao->Sample(
			scaled.x, scaled.y,
			mipOverride ? 0 : TriUVInfoToTexLOD(mrao, textureLodInfo)
		);
		glm::vec2 metalnessRoughness(pixelMRAO.r, pixelMRAO.g);

		if (mrao2 != nullptr) {
			pixelMRAO = mrao2->Sample(
				scaled2.x, scaled2.y,
				mipOverride ? 0 : TriUVInfoToTexLOD(mrao2, textureLodInfo)
			);
			glm::vec2 metalnessRoughness2(pixelMRAO.r, pixelMRAO.g);

			metalnessRoughness = glm::lerp(metalnessRoughness, metalnessRoughness2, blendFactor);
		}

		metalness = metalnessRoughness.r;
		roughness = metalnessRoughness.g;
	}

	shadingDataSet = true;
}

const glm::vec3& TraceResult::GetPos()
{
	if (!posSet) {
		pos = uvw.z * v[0] + uvw.x * v[1] + uvw.y * v[2];
		posSet = true;
	}
	return pos;
}

const glm::vec3& TraceResult::GetNormal()
{
	CalcTBN();
	return normal;
}
const glm::vec3& TraceResult::GetTangent()
{
	CalcTBN();
	return tangent;
}
const glm::vec3& TraceResult::GetBinormal()
{
	CalcTBN();
	return binormal;
}

const glm::vec3& TraceResult::GetAlbedo()
{
	CalcShadingData();
	return albedo;
}
float TraceResult::GetAlpha()
{
	CalcShadingData();
	return alpha;
}

float TraceResult::GetMetalness()
{
	CalcShadingData();
	return metalness;
}
float TraceResult::GetRoughness()
{
	CalcShadingData();
	return roughness;
}

float TraceResult::GetBaseMIPLevel()
{
	CalcFootprint();
	return mipOverride ? 0 : TriUVInfoToTexLOD(baseTexture, textureLodInfo);
}
