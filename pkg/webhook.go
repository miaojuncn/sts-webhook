package pkg

import (
	"context"
	"fmt"

	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// +kubebuilder:webhook:path=/mutate,mutating=true,failurePolicy=fail,groups="apps",resources=statefulsets,verbs=create;update,versions=v1,name=mj

// StatefulSetVolume snapshot volume
type StatefulSetVolume struct {
	Client client.Client
}

func (a *StatefulSetVolume) Default(ctx context.Context, obj runtime.Object) error {
	sts, ok := obj.(*appsv1.StatefulSet)
	if !ok {
		return fmt.Errorf("expected a StatefulSet but got a %T", obj)
	}

	if sts.Annotations == nil {
		sts.Annotations = map[string]string{}
	}

	sts.Annotations["example-mutating-admission-webhook"] = "foo"

	return nil
}
