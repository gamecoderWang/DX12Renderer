#include "MaterialPool.h"
#include "ConstantBuffer.h"
#include "ShaderPool.h"
#include "CommonTexture.h"
#include "TexturePool.h"
#include "Material.h"
#include <DirectXMath.h>
#include "MathHelper.h"

namespace rdr
{
	using namespace DirectX;

	MaterialPool::MaterialPool(const Renderer& InRenderer)
		: renderer(InRenderer)
	{
		using AnyVector = std::vector<std::pair<std::string, std::any>>;

		//TODO:���ʺ����������Ŀǰ�ܻ��ң���ʱ����ô����
		AddMaterial("ShadowMap", "ShadowMap", { {"WorldMatrix", Math::Identity4x4() } });

		const auto& tPtrSkyBox = AddMaterial("SkyBox", "SkyBox", { {"WorldMatrix", Math::Identity4x4() } });
		tPtrSkyBox->BindTexture("SkyBox", renderer);
		tPtrSkyBox->BindSampler(0);

		AddMaterial("DrawNormal", "DrawNormal", { {"WorldMatrix", Math::Identity4x4() } });

#if SSAO
		const AnyVector& tSsaoCBuffer = { {"OcclusionFadeStart", 2.0f } , {"OcclusionFadeEnd", 10.0f }, {"SurfaceEpsilon", 2.0f }, {"SSAORadius", 15.0f } };
		const auto& tPtrSsaoMat = AddMaterial("Ssao", "Ssao", tSsaoCBuffer);
		tPtrSsaoMat->BindTexture("ScreenNormal", renderer);
		tPtrSsaoMat->BindTexture("SsaoDepthTex", renderer);
		tPtrSsaoMat->BindTexture("RandomVecTex", renderer);
		tPtrSsaoMat->BindSampler(0);
		tPtrSsaoMat->BindSampler(2);
		tPtrSsaoMat->BindSampler(3);

		const auto& tWeights = Math::CalcGaussWeights(2.5f);
		AnyVector tSsaoBlurCBuffer =
		{
			{"BlurWeights0",XMFLOAT4(&tWeights[0]) }, {"BlurWeights1",  XMFLOAT4(&tWeights[4])}, {"BlurWeights2", XMFLOAT4(&tWeights[8]) },
			{"InvRenderTargetSize", XMFLOAT4(1.0f / global_SSAOMapWidth, 1.0f / global_SSAOMapHeight, 0, 0) }, {"HorizontalBlur", true }
		};
		const auto& tPtrSsaoBlur = AddMaterial("SsaoBlurHorizontal", "SsaoBlur", tSsaoBlurCBuffer);
		tPtrSsaoBlur->BindTexture("SsaoTex", renderer);
		tPtrSsaoBlur->BindTexture("ScreenNormal", renderer);
		tPtrSsaoBlur->BindSampler(0);

		tSsaoBlurCBuffer[tSsaoBlurCBuffer.size() - 1].second = false;
		const auto& tPtrSsaoBlurVer = AddMaterial("SsaoBlurVertical", "SsaoBlur", tSsaoBlurCBuffer);
		tPtrSsaoBlurVer->BindTexture("SsaoBlur", renderer);
		tPtrSsaoBlurVer->BindTexture("ScreenNormal", renderer);
		tPtrSsaoBlurVer->BindSampler(0);
#endif
	}

	MaterialPool::~MaterialPool()
	{
	}

	std::shared_ptr<Material> MaterialPool::AddMaterial(const std::string& InName, const std::string& InShaderName, const std::vector<std::pair<std::string, std::any>>& InCBufferData)
	{
		const auto& tIndex = MaterialData.find(InName);
		if (tIndex != MaterialData.cend())
			throw "Two Materials Have The Same Name";
		const std::shared_ptr<Shader>& tPtrShader = renderer.GetShaderPool()->GetShader(InShaderName);
		std::shared_ptr<Material> ptrMat = std::make_shared<Material>(InName, tPtrShader);
		ptrMat->CreateConstBuffer(renderer, InCBufferData);
		MaterialData.insert({ InName, ptrMat });
		return ptrMat;
	}

	std::shared_ptr<Material> MaterialPool::AddMaterialFromSponzaMesh(const std::string& meshName)
	{
		static uint32_t phongMatNum = 0;

		std::string tempName = meshName;
		for (size_t length = tempName.size(), i = 0, count = 0; i < length; ++i)
		{
			if (tempName[i] == '_') ++count;
			if (count == 4)
			{
				tempName = tempName.substr(i + 1);
				break;
			}
		}
		std::string diffuseName = tempName + "_diffuse", normalName;
		if (tempName.substr(0, 6) == "fabric") normalName = "fabric_normal";
		else normalName = tempName + "_normal";

		if(renderer.GetTexPool()->ContainTexture(diffuseName) == false)
		{
			diffuseName = "DefaultDiffuse";
			normalName = "DefaultNormal";
		}

		std::string matName = "Material" +std::to_string(phongMatNum);
		phongMatNum++;
		const std::vector<std::pair<std::string, std::any>>& tCBufferValue =
		{
			{"WorldMatrix", Math::Identity4x4() },{"NormalWorldMatrix", Math::Identity4x4() }, {"Diffuse", XMFLOAT4(1.0f, 1.0f, 1.0f, 1.0f) },
			{"Ambient", XMFLOAT4(0.4f, 0.4f, 0.4f, 1.0f) }, {"Specular", XMFLOAT4(1.0f, 1.0f, 1.0f, 1.0f) }, {"FresnelR0", XMFLOAT3(0.1f, 0.1f, 0.1f) },
			{"Shininess", 0.98f },{"LightColor",  XMFLOAT3(1.0f, 1.0f, 1.0f)},{"FallOffStart", 0.0f }, {"Direction",  XMFLOAT4(0.0f, -0.8f, 0.3f, 0)},
			{"PointPos", XMFLOAT3(0.0f, 0.0f, 0.0f) }, {"FallOffEnd", 0.0f }
		};
		const auto& ptrMat = AddMaterial(matName, "Phong", tCBufferValue);
		ptrMat->BindTexture(diffuseName,renderer);
		ptrMat->BindTexture(normalName, renderer);
		ptrMat->BindTexture("ShadowMapTex", renderer);
#if SSAO
		ptrMat->BindTexture("SsaoTex", renderer);
#endif
		ptrMat->BindSampler(0);
		ptrMat->BindSampler(1);
		return ptrMat;
	}


	const std::shared_ptr<Material>& MaterialPool::GetMaterial(const std::string& InName)
	{
		const std::shared_ptr<Material>& tPtrMat = MaterialData[InName];
		if (tPtrMat == nullptr) throw "No Such Material";
		return tPtrMat;
	}
}
